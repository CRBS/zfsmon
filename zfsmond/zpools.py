class ZPool(object):
    def __init__(self, name, size, health):
        self.name = name
        self.cap = ""
        self.dedup = ""
        self.health = health
        self.altroot = "-"
        
        # Sizes/capacities can be passed as either an integer size in bytes or a decimal 
        # string followed by a single letter (M, G, T, etc.)
        self.size = parse_size(size)

        self.free = 0
        self.allocated = 0


    def parse_size(size):
        MULTIPLIERS = {'K': 2**10, 'M': 2**20, 'G': 2**30, 'T': 2**40, 'P': 2**50}
         try:
            sint = int(size)
            return sint
         except ValueError:
            for m in MULTIPLIERS.iterkeys():
                size = size.strip()
                if m in size:
                    return int( float([:len(size)-1]) * MULTIPLIERS[m] )
         raise ValueError("Could not parse " + size + " as a size in bytes.")

            
            
