import importlib.util
import pathlib
import unittest

PATH = pathlib.Path(__file__).resolve().parents[1] / 'scripts' / 'validate-lab-cidrs.py'
SPEC = importlib.util.spec_from_file_location('validate_cidrs', PATH)
MOD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MOD)

class TestLabCIDRs(unittest.TestCase):
    def test_rfc1918(self):
        for x in ('10.40.0.3/32', '10.2.3.0/24', '172.16.4.0/24',
                  '172.31.5.9/32', '192.168.136.0/24', '192.168.1.114/32'):
            with self.subTest(x=x): self.assertEqual(MOD.validate(x).version, 4)

    def test_rejected(self):
        for x in ('0.0.0.0/0', '::/0', '::1/128', '127.0.0.1/32',
                  '169.254.20.1/32', '192.0.2.10/32', '198.51.100.3/32',
                  '203.0.113.4/32', '100.64.0.1/32', '8.8.8.8/32',
                  '192.168.0.0/16', '172.16.0.0/12', '10.0.0.0/8',
                  '10.0.0.0/7', 'bad', '192.168.1.0/33'):
            with self.subTest(x=x), self.assertRaises(ValueError): MOD.validate(x)

if __name__ == '__main__':
    unittest.main()
