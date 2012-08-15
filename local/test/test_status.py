import sys
import unittest
import status

class TestZpoolStatus(unittest.TestCase):
    def setUp(self):
        with open("fixtures/zpool_status.txt", "r") as f:
            status = []
            self.pools = []
            first_pool = True
            for line in f:
                if 'pool:' in line:
                    if first_pool:
                        first_pool = False
                    else:
                        self.pools.append(''.join(status))
                        status = []
                status.append(line)
            self.pools.append(''.join(status))

    def test_pool(self):
        for ps in self.pools:
            p = status.PoolStatus(ps)
            assert p is not None
            assert p.json is not None

if __name__ == '__main__':
    unittest.main()
