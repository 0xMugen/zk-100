# Test outputting a large literal value

NODE (0,0)
HLT

NODE (0,1)
HLT

NODE (1,0)
HLT

NODE (1,1)
# Output literal 4294967295 (max u32)
MOV 4294967295, ACC
MOV ACC, OUT
HLT