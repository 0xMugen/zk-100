# Test outputting a literal value - no input needed

NODE (0,0)
HLT

NODE (0,1)
HLT

NODE (1,0)
HLT

NODE (1,1)
# Output literal 42
MOV 42, ACC
MOV ACC, OUT
HLT