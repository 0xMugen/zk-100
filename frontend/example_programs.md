# ZK-100 Example Programs

## Simple Pass-Through
This program reads a value from IN and passes it to OUT.

Node (0,0):
```
MOV IN ACC
MOV ACC RIGHT
```

Node (1,0):
```
MOV LEFT ACC
MOV ACC DOWN
```

Node (1,1):
```
MOV UP ACC
MOV ACC OUT
```

Node (0,1):
```
NOP
```

## Add Two Numbers
This program reads two numbers from IN and outputs their sum.

Node (0,0):
```
MOV IN ACC
MOV ACC RIGHT
MOV IN ACC
MOV ACC RIGHT
```

Node (1,0):
```
MOV LEFT ACC
MOV ACC DOWN
MOV LEFT ACC
ADD DOWN
MOV ACC DOWN
```

Node (1,1):
```
MOV UP ACC
MOV ACC OUT
```

Node (0,1):
```
NOP
```

## Negate Number
This program reads a number and outputs its negative.

Node (0,0):
```
MOV IN ACC
NEG
MOV ACC RIGHT
```

Node (1,0):
```
MOV LEFT ACC
MOV ACC DOWN
```

Node (1,1):
```
MOV UP ACC
MOV ACC OUT
```

Node (0,1):
```
NOP
```