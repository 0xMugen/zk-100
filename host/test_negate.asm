# Program that negates input values
# Input: Array of numbers
# Output: Negated numbers

NODE (0,0)
# Read all inputs and negate them
loop:
    MOV IN, ACC
    JZ done      # If zero (no more input), we're done
    NEG          # Negate the value
    MOV ACC, P:RIGHT
    JMP loop
done:
    MOV 0, P:RIGHT  # Send terminator
    HLT

NODE (0,1)
# Pass data from left to down
pass_loop:
    MOV P:LEFT, ACC
    JZ end_pass
    MOV ACC, P:DOWN
    JMP pass_loop
end_pass:
    MOV 0, P:DOWN
    HLT

NODE (1,0)
# Pass data from up to right
forward_loop:
    MOV P:UP, ACC
    JZ end_forward
    MOV ACC, P:RIGHT
    JMP forward_loop
end_forward:
    MOV 0, P:RIGHT
    HLT

NODE (1,1)
# Write all values to output
output_loop:
    MOV P:LEFT, ACC
    JZ finish
    MOV ACC, OUT
    JMP output_loop
finish:
    HLT