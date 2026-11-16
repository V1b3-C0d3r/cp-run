"""Pinned school policy survives imports without overwriting personal routing."""
import copy
import unittest
from _paths import load_engine

engine = load_engine('school_settings_contracts')


class SchoolSettingsTest(unittest.TestCase):
    def test_pinned_policy_preserves_routing_and_unrelated_profiles(self):
        data = copy.deepcopy(engine.FACTORY_SETTINGS)
        data['MODE_C_GCC']['school'] = '-O0'
        data['MODE_DEST_DIR']['school'] = '.bin'
        data['MODE_SAVE_RELPATH']['school'] = '1'
        other = {key: copy.deepcopy(data[key].get('debug')) for key in engine.PROFILE_KEYS}
        engine.normalize_school_preset(data)
        self.assertEqual(data['MODE_C_GCC']['school'], engine.shlex.join(engine.SCHOOL_C_FLAGS))
        self.assertEqual(data['MODE_DEST_DIR']['school'], '.bin')
        self.assertEqual(data['MODE_SAVE_RELPATH']['school'], '1')
        for key, value in other.items():
            self.assertEqual(data[key].get('debug'), value)

    def test_copy_is_customizable_and_not_normalized_back_to_school(self):
        data = copy.deepcopy(engine.FACTORY_SETTINGS)
        data['MODE_NAMES'].append('practice')
        for key in engine.PROFILE_KEYS:
            if 'school' in data[key]:
                data[key]['practice'] = data[key]['school']
        data['MODE_C_GCC']['practice'] = '-O0 -std=c11'
        engine.normalize_school_preset(data)
        self.assertEqual(data['MODE_C_GCC']['practice'], '-O0 -std=c11')
        self.assertNotEqual(data['MODE_C_GCC']['school'], data['MODE_C_GCC']['practice'])

    def test_explicit_profile_removal_is_preserved(self):
        data = copy.deepcopy(engine.FACTORY_SETTINGS)
        data['MODE_NAMES'].remove('school')
        for key in engine.PROFILE_KEYS:
            data[key].pop('school', None)
        engine.normalize_school_preset(data)
        self.assertNotIn('school', data['MODE_NAMES'])
        self.assertTrue(all('school' not in data[key] for key in engine.PROFILE_KEYS))
