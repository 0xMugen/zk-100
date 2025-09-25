# Test NEG with 1 - should output 4294967295 (two's complement of -1)

NODE (0,0)
# Put 1 in ACC and negate it
MOV 1, ACC
NEG
MOV ACC, P:RIGHT
HLT

NODE (0,1)
# Pass data from left to down
MOV P:LEFT, ACC
MOV ACC, P:DOWN
HLT

NODE (1,0)
# Pass data from up to right  
MOV P:UP, ACC
MOV ACC, P:RIGHT
HLT

NODE (1,1)
# Write data from left to output
MOV P:LEFT, ACC
MOV ACC, OUT
HLT