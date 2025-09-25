# Direct negate test - only uses two nodes

NODE (0,0)
# Read input, negate, send right
MOV IN, ACC
NEG
MOV ACC, P:RIGHT
HLT

NODE (0,1)
# Receive from left and output immediately
MOV P:LEFT, OUT
HLT

NODE (1,0)
HLT

NODE (1,1)
HLT