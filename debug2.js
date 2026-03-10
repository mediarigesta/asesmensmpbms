// Test how template literals handle \$
const a = `test\$var`;
const b = `test$var`;
console.log('a:', JSON.stringify(a)); // \$ in template literal
console.log('b:', JSON.stringify(b)); // $ in template literal

// Check the actual file
const fs = require('fs');
const file = fs.readFileSync('lib/main.dart', 'utf8');
const idx = file.indexOf('aktif Aktif');
console.log('File content around aktif Aktif:', JSON.stringify(file.substring(idx-10, idx+20)));

// What does the patch's template literal produce?
// Line 136 has \$ (backslash + dollar) in source
// In a template literal, \$ → ... let's see
const test = `Text("\$aktif Aktif", style: ...)`;
console.log('Template literal with \\$:', JSON.stringify(test));
