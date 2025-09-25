# Echo program - just outputs the input unchanged
# This will help diagnose if the issue is with NEG or with I/O

NODE (0,0)
# Read input and send right
MOV IN, ACC
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