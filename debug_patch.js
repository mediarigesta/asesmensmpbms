const fs = require('fs');
const src = fs.readFileSync('patch_dashboard_v1.js', 'utf8');
const lines = src.split('\n');
const line = lines[135];
console.log('Line 136 chars around $:');
for (let i = 0; i < line.length; i++) {
  const c = line.charCodeAt(i);
  if (c === 92 || c === 36) { // backslash or dollar
    console.log('pos ' + i + ': char=' + line[i] + ' code=' + c + ' context=' + line.substring(i-3, i+6));
  }
}
