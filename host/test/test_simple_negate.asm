# Simple negate program - negates a single input value
# No loops, no terminators - just one value

NODE (0,0)
# Read input and negate it
MOV IN, ACC
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