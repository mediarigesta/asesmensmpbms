const fs = require('fs');
let src = fs.readFileSync('patch_dashboard_v1.js', 'utf8');

// Line 136 (index 135): the find-string has \$ which evaluates to $ in template literal
// But the file has \$ (one backslash + dollar). So we need \\$ in the template literal.
// Replace the specific problematic line in the find-string
const lines = src.split('\n');

// Line 136 (index 135) - in the FIND string for change 3
// Change: Text("\$aktif Aktif" → Text("\\$aktif Aktif"
// The source file has \$ (backslash=92, dollar=36) on this line
// We need to add another backslash before the existing backslash
// char 24 is the backslash, char 25 is dollar
const line135 = lines[135];
const newLine = line135.substring(0, 24) + '\\' + line135.substring(24);
console.log('Old line 136:', JSON.stringify(line135.trim()));
console.log('New line 136:', JSON.stringify(newLine.trim()));
lines[135] = newLine;

src = lines.join('\n');
fs.writeFileSync('patch_dashboard_v1.js', src, 'utf8');
console.log('Fixed!');

// Verify
const verify = require('fs').readFileSync('patch_dashboard_v1.js', 'utf8').split('\n')[135];
const tmpl = eval('`' + verify.trim() + '`');
console.log('Verified value contains backslash-dollar:', tmpl.includes('\\$aktif'));
