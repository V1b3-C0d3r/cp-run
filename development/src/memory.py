"""Platform resident-memory backends used only when observation requires RSS."""

import ctypes
import errno
import os
import sys

class MacMemory:
    """Read process-group resident bytes directly through macOS libproc."""

    class TaskInfo(ctypes.Structure):
        _fields_ = [(name, ctypes.c_uint64) for name in (
            "virtual_size", "resident_size", "total_user", "total_system",
            "threads_user", "threads_system",
        )] + [("remaining", ctypes.c_int32 * 12)]

    def __init__(self):
        self.lib = ctypes.CDLL("/usr/lib/libproc.dylib", use_errno=True)
        self.lib.proc_listpids.argtypes = [ctypes.c_uint32, ctypes.c_uint32,
                                          ctypes.c_void_p, ctypes.c_int]
        self.lib.proc_listpids.restype = ctypes.c_int
        self.lib.proc_pidinfo.argtypes = [ctypes.c_int, ctypes.c_int,
                                         ctypes.c_uint64, ctypes.c_void_p,
                                         ctypes.c_int]
        self.lib.proc_pidinfo.restype = ctypes.c_int

    def sample(self, group):
        # Query only the child's group. Unrelated processes do not add memory
        # or permission errors, and no external ps command is needed per tick.
        ctypes.set_errno(0)
        size = self.lib.proc_listpids(2, group, None, 0)  # PROC_PGRP_ONLY = 2.
        if size < 0 or (size == 0 and ctypes.get_errno() not in (0, errno.ESRCH)):
            raise OSError(ctypes.get_errno(), "proc_listpids")
        slots = max(16, size // ctypes.sizeof(ctypes.c_int) + 16)
        while True:
            pids = (ctypes.c_int * slots)()
            ctypes.set_errno(0)
            count = self.lib.proc_listpids(2, group, pids, ctypes.sizeof(pids))
            if count < 0 or (count == 0 and ctypes.get_errno() not in (0, errno.ESRCH)):
                raise OSError(ctypes.get_errno(), "proc_listpids")
            if count < ctypes.sizeof(pids):
                break
            slots *= 2  # Membership may grow between sizing and retrieval.

        total = 0
        for pid in pids[:count // ctypes.sizeof(ctypes.c_int)]:
            if pid <= 0:
                continue
            info = self.TaskInfo()
            ctypes.set_errno(0)
            size = self.lib.proc_pidinfo(pid, 4, 0, ctypes.byref(info),
                                         ctypes.sizeof(info))  # PROC_PIDTASKINFO.
            if size == ctypes.sizeof(info):
                total += info.resident_size
            elif size <= 0 and ctypes.get_errno() not in (0, errno.ESRCH):
                raise OSError(ctypes.get_errno(), "proc_pidinfo")
            elif size > 0:
                raise OSError(errno.EIO, "incomplete proc_taskinfo")
        return total


class LinuxMemory:
    """Sum RSS pages in the child's process group on secondary Linux hosts."""

    def __init__(self):
        self.page_size = os.sysconf("SC_PAGE_SIZE")

    def sample(self, group):
        total = 0
        for entry in os.scandir("/proc"):
            if not entry.name.isdigit():
                continue
            try:
                if os.getpgid(int(entry.name)) != group:
                    continue
                # A command can contain spaces and ')'; stat fields begin
                # after the final ')'. RSS is field 24, pgrp is field 5.
                with open(entry.path + "/stat", encoding="ascii", errors="replace") as stream:
                    fields = stream.read().rsplit(")", 1)[1].split()
                if int(fields[2]) == group:
                    total += int(fields[21]) * self.page_size
            except (FileNotFoundError, ProcessLookupError):
                pass  # A group member may exit between membership and RSS.
            except PermissionError:
                # Never silently advertise a limit that could not be observed.
                try:
                    belongs = os.getpgid(int(entry.name)) == group
                except (ProcessLookupError, PermissionError):
                    belongs = False
                if belongs:
                    raise
        return total


