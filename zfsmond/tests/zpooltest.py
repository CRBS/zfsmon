import unittest
import sys
from ..src.zpools import ZPool, parse_size
class TestZPoolFunctions(unittest.TestCase):
    def setUp(self):
        self.VALID_SIZE_VALUES = {'1030134': 1030134, '500K': 512 * 1000, '1.23M': 1.29 * 1000 * 1000, '9.3T': 1.02 * 10**13, 
                                    '144T': 1.583 * 10**14, '1P': 1.126 * 10**15, '1.0P': 1.126 * 10**15, '999K': 1.023 * 10**6, 
                                    '999.9K': 1.0239 * 10**6, '999P': 1.125 * 10**18, '999.9P': 1.1258 * 10**18}
        self.INVALID_SIZE_VALUES = ["f", "2Z", "&"]

    def test_validparse(self):
        for size in self.VALID_SIZE_VALUES.iterkeys():
            sys.stderr.write("Comparing parse_size(" + str(size) + ") with " + str(self.VALID_SIZE_VALUES[size]) + "\n")
            self.assertEquals( parse_size( size ), self.VALID_SIZE_VALUES[size] )

if __name__ == "__main__":
    unittest.main()
