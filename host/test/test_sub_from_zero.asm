# Test subtraction from zero to simulate negation

NODE (0,0)
# Read input, subtract from 0, send right
MOV IN, ACC
MOV 0, ACC
SUB 5  # This should give 0 - 5 = -5 (as unsigned: 4294967291)
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