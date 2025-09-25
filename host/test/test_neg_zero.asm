# Test NEG with zero - should output zero

NODE (0,0)
# Put zero in ACC and negate it
MOV 0, ACC
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