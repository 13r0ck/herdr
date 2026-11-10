import { expect, test } from 'bun:test';
import { commandAt, copyItem } from '../defaults/mods/menu/command.js';
const row = (text, semantic=0, wraps=false) => ({wraps, cells:Array.from(text, (text,x)=>({text,x,semantic,used:true}))});
const snapshot = () => ({ clicked:[1,0], rows:[row('$ echo x',1),row('x'),row('')], cursor:[2,0], boundaries:[{kind:1,prompt:0,at:[0,0]},{kind:3,at:[1,0]},{kind:4,at:[2,0]}] });
test('selects from input or output; preserves output newline',()=>{
 const s=snapshot(); s.rows[0].cells[0].semantic=2; s.rows[0].cells[1].semantic=2;
 expect(commandAt(s)).toEqual({command:'echo x',output:'x\n'});
 s.clicked=[0,3]; expect(commandAt(s)?.command).toBe('echo x');
});
test('requires retained submitted boundaries and primary screen',()=>{
 for(const change of [{alternate:true},{boundaries:[]},{boundaries:[{kind:1,prompt:0,at:[0,0]}]}]) expect(commandAt({...snapshot(),...change})).toBeNull();
});
test('empty output and running output are valid',()=>{
 const s=snapshot(); s.boundaries[2].at=[1,0]; expect(commandAt({...s,clicked:[0,3]})?.output).toBe('');
 s.boundaries.pop(); s.cursor=[1,1]; expect(commandAt(s)?.output).toBe('x');
});
test('joins wraps, preserves blank lines, indentation, Unicode and prompt-like output',()=>{
 const s=snapshot(); s.rows=[row('echo ',1,true),row('界',1),row('  $ x'),row(''),row('end'),row('')]; s.clicked=[3,0]; s.boundaries[1].at=[2,0];s.boundaries[2].at=[5,0];
 expect(commandAt(s)).toEqual({command:'echo 界',output:'  $ x\n\nend\n'});
});
test('adjacent commands on the same row use exact boundary cells',()=>{
 const s=snapshot();s.rows=[row('abcDEF')];s.clicked=[0,4];s.boundaries=[{kind:1,prompt:0,at:[0,0]},{kind:3,at:[0,1]},{kind:4,at:[0,3]},{kind:1,prompt:0,at:[0,3]},{kind:3,at:[0,4]},{kind:4,at:[0,6]}];
 expect(commandAt(s)?.output).toBe('EF');
});

test('excludes continuation and right prompts using semantic cells',()=>{
 const s=snapshot();s.rows=[row('one',1),row('> two',1),row('')];s.rows[1].cells[0].semantic=2;s.rows[1].cells[1].semantic=2;
 s.boundaries[1].at=[2,0];s.boundaries[2].at=[2,0];s.clicked=[1,2];
 expect(commandAt(s)?.command).toBe('one\ntwo');
});

test('an explicitly discarded completion boundary is unavailable',()=>{
 const s=snapshot(); s.boundaries[2].at=null; expect(commandAt(s)).toBeNull();
});

test('Copy includes command and output without a selection',()=>{
 const s=snapshot();s.rows[0].cells[0].semantic=2;s.rows[0].cells[1].semantic=2;
 expect(copyItem(s)).toEqual(['Copy','clipboard',{text:'echo x\nx\n'},false]);
 s.boundaries[2].at=[1,0];s.clicked=[0,3];
 expect(copyItem(s)).toEqual(['Copy','clipboard',{text:'echo x\n'},false]);
});
test('Copy Selected takes precedence over the clicked command and works in alternate screens',()=>{
 const s={...snapshot(),selection:'  chosen 界\n\n',alternate:true};
 expect(copyItem(s)).toEqual(['Copy Selected','clipboard',{text:s.selection},false]);
});
test('Copy is disabled for unmarked text without a selection',()=>{
 expect(copyItem({})).toEqual(['Copy','clipboard',{text:undefined},true]);
});
