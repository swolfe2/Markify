import struct

is_64bit = struct.calcsize("P") * 8 == 64

some_dict = {"user": "marco", "address": "some st.", "age": 28}
