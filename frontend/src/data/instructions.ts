export interface Instruction {
  name: string;
  syntax: string;
  description: string;
  examples: string[];
  category: 'data' | 'arithmetic' | 'control' | 'special';
}

export const instructions: Instruction[] = [
  // Data Movement
  {
    name: 'MOV',
    syntax: 'MOV <source> <destination>',
    description: 'Move data from source to destination',
    examples: [
      'MOV IN ACC      # Read input into accumulator',
      'MOV ACC OUT     # Write accumulator to output',
      'MOV 42 ACC      # Load constant 42 into ACC',
      'MOV ACC RIGHT   # Send ACC value to right port',
      'MOV LEFT ACC    # Read from left port into ACC',
    ],
    category: 'data',
  },
  
  // Arithmetic
  {
    name: 'ADD',
    syntax: 'ADD <source>',
    description: 'Add source to ACC and store result in ACC',
    examples: [
      'ADD 5          # ACC = ACC + 5',
      'ADD RIGHT      # ACC = ACC + value from right port',
    ],
    category: 'arithmetic',
  },
  {
    name: 'SUB',
    syntax: 'SUB <source>',
    description: 'Subtract source from ACC and store result in ACC',
    examples: [
      'SUB 3          # ACC = ACC - 3',
      'SUB LEFT       # ACC = ACC - value from left port',
    ],
    category: 'arithmetic',
  },
  {
    name: 'NEG',
    syntax: 'NEG',
    description: 'Negate the value in ACC (multiply by -1)',
    examples: [
      'NEG            # ACC = -ACC',
    ],
    category: 'arithmetic',
  },
  
  // Control Flow
  {
    name: 'JMP',
    syntax: 'JMP <label>',
    description: 'Unconditional jump to label',
    examples: [
      'JMP loop       # Jump to loop label',
      'JMP end        # Jump to end label',
    ],
    category: 'control',
  },
  {
    name: 'JEZ',
    syntax: 'JEZ <label>',
    description: 'Jump to label if ACC equals zero',
    examples: [
      'JEZ done       # Jump to done if ACC == 0',
    ],
    category: 'control',
  },
  {
    name: 'JNZ',
    syntax: 'JNZ <label>',
    description: 'Jump to label if ACC is not zero',
    examples: [
      'JNZ continue   # Jump to continue if ACC != 0',
    ],
    category: 'control',
  },
  {
    name: 'JGZ',
    syntax: 'JGZ <label>',
    description: 'Jump to label if ACC is greater than zero',
    examples: [
      'JGZ positive   # Jump to positive if ACC > 0',
    ],
    category: 'control',
  },
  {
    name: 'JLZ',
    syntax: 'JLZ <label>',
    description: 'Jump to label if ACC is less than zero',
    examples: [
      'JLZ negative   # Jump to negative if ACC < 0',
    ],
    category: 'control',
  },
  
  // Special
  {
    name: 'NOP',
    syntax: 'NOP',
    description: 'No operation (do nothing)',
    examples: [
      'NOP            # Do nothing',
    ],
    category: 'special',
  },
];

export const specialRegisters = [
  {
    name: 'ACC',
    description: 'Accumulator - Main working register for arithmetic',
    usage: 'Used as source or destination in MOV, implicit target for ADD/SUB/NEG',
  },
  {
    name: 'NIL',
    description: 'Null register - Always reads as 0, writes are discarded',
    usage: 'MOV NIL RIGHT sends 0 to right port',
  },
  {
    name: 'IN',
    description: 'Input register - Reads next value from program input',
    usage: 'Only available in node (0,0)',
  },
  {
    name: 'OUT',
    description: 'Output register - Writes value to program output',
    usage: 'Only available in node (1,1)',
  },
];

export const ports = [
  {
    name: 'UP',
    description: 'Port to node above',
    connections: {
      '(0,0)': 'No connection (edge)',
      '(1,0)': 'No connection (edge)',
      '(0,1)': 'Connects to (0,0)',
      '(1,1)': 'Connects to (1,0)',
    },
  },
  {
    name: 'DOWN',
    description: 'Port to node below',
    connections: {
      '(0,0)': 'Connects to (0,1)',
      '(1,0)': 'Connects to (1,1)',
      '(0,1)': 'No connection (edge)',
      '(1,1)': 'No connection (edge)',
    },
  },
  {
    name: 'LEFT',
    description: 'Port to node on the left',
    connections: {
      '(0,0)': 'No connection (edge)',
      '(1,0)': 'Connects to (0,0)',
      '(0,1)': 'No connection (edge)',
      '(1,1)': 'Connects to (0,1)',
    },
  },
  {
    name: 'RIGHT',
    description: 'Port to node on the right',
    connections: {
      '(0,0)': 'Connects to (1,0)',
      '(1,0)': 'No connection (edge)',
      '(0,1)': 'Connects to (1,1)',
      '(1,1)': 'No connection (edge)',
    },
  },
];