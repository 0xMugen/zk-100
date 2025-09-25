# Simple test program for ZK-100
# Reads input from (0,0) and passes it to output at (1,1)

NODE (0,0)
# Read input and send right
MOV IN, P:RIGHT
HLT

NODE (0,1)
# Pass data from left to down
MOV P:LEFT, P:DOWN
HLT

NODE (1,0)
# Pass data from up to right
MOV P:UP, P:RIGHT
HLT

NODE (1,1)
# Write data from left to output
MOV P:LEFT, OUT
HLT