import * as raddle from "../content/raddle.xql";
import * as op from "op.xql";
import * as n from "n.xql";
import * as a from "array-util.xql";


export function elem_3($frame,$name,$content) /*Item*/ {

return n.element_2($name,$content)

};

export function attr_3($frame,$name,$content) /*Item*/ {

return n.attribute_2($name,$content)

};

export function text_2($frame,$content) /*Item*/ {

return n.text_1($content)

};

export function define_6($frame,$name,$desc,$args,$type,$body) /*Item*/ {

let $map = new Item(a.foldLeftAt_3($args,{},function($pre,$_,$i) /*fn.item_0()*/ {

$_($frame)

}));

return map.new_1(($frame,map.entry_2("$functions",{}),map.entry_2("$exports",map.put_4($frame("$exports"),fn.concat_3($name,"#",array.size_1($args)),(n.bind_3($body,$args,$type)($frame))))))

};

export function describe_5($frame,$name,$desc,$args,$type) /*Item*/ {

return map.put_3($frame,fn.concat_3($name,"#",array.size_1($args)),{"name":$name,"description":$desc})

};

export function function_3($args,$type,$body) /*Item*/ {

return n.bind_3($body,$args,$type)

};

export function typecheck_2($type,$val) /*Item*/ {

if(util.eval_1(fn.concat_2("$val instance of ",$type))) { return console.log_1(($val,$type)); } else {return console.log_1("Not of correct type");}

};

export function getNameSuffix_1($name) /*Item*/ {

let $cp = new Item(fn.stringToCodepoints_1($name));

if($cpfn.last_0() == 4243456395) { return fn.codepointsToString_1(fn.reverse_1(fn.tail_1(fn.reverse_1($cp)))); } else {return $name;}

};

export function typegen_4($frame,$type,$name,$val) /*Item*/ {

return map.put_3($frame,$name,$val)

};

export function typegen_3($frame,$type,$name) /*Item*/ {

return function($frame,$val,$i) /*fn.item_0()*/ {

(let $val = new Item(if(fn.empty_1($val)) { return $type; } else {return $val;}),map.put_3($frame,if($name == "") { return new String($i); } else {return $name;},$val))

}

};

export function item_0() /*Item*/ {

return "core:item()"

};

export function item_2($frame,$name) /*Item*/ {

return $name

};

export function item_3($frame,$name,$val) /*Item*/ {

return let $$name = new $frame($val)

};

export function integer_0() /*Item*/ {

return "xs:integer"

};

export function integer_2($frame,$name) /*Item*/ {

return $name

};

export function integer_3($frame,$name,$val) /*Item*/ {

return let $$name = new $frame($val)

};

export function string_0() /*Item*/ {

return "xs:string"

};

export function string_2($frame,$name) /*Item*/ {

return $name

};

export function string_3($frame,$name,$val) /*Item*/ {

return let $$name = new $frame($val)

};

export function apply_3($frame,$name,$args) /*Item*/ {

let $self = new Item(isCurrentModule_2($frame,$name));

let $f = new Item(resolveFunction_3($frame,$name,$self));

let $frame = new Item(map.put_3($frame,"$callstack",array.append_2($frame("$callstack"),$name)));

let $frame = new Item(map.put_3($frame,"$caller",$name));

if($self) { return $f(processArgs_2($frame,$args)); } else {return fn.apply_2($f,processArgs_2($frame,$args));}

};

function isCurrentModule_2($frame,$name) /*Item*/ {

map.contains_2($frame,"$prefix") && fn.matches_2($name,fn.concat_3("^",$frame("$prefix"),":"))

};

export function resolveFunction_2($frame,$name) /*Item*/ {

return resolveFunction_3($frame,$name,$self)

};

export function resolveFunction_3($frame,$name,$self) /*Item*/ {

if($self) { return ($frame("$exports")($name)); } else {return let $parts = new Item(fn.tokenize_2($name,":")),let $prefix = new Item(if(filterAt_2($parts,$_0 == 2)) { return filterAt_2($parts,$_0 == 1); } else {return "";}),let $module = new Item(($frame("$imports")($prefix))),let $theirname = new Item(fn.concat_2(if($module("$prefix")) { return fn.concat_2($module("$prefix"),":"); } else {return "";},$partsfn.last_0())),$module("$exports")($theirname);}

};

export function processArgs_2($frame,$args) /*Item*/ {

return a.forEachAt_2($args,function($arg,$at) /*fn.item_0()*/ {

if($arg instance of Item) { return let $is-params = new Item($frame("$caller") == "core:define#6" && $at == 4 || $frame("$caller") == "core:function#3" && $at == 1),let $is-body = new Item($frame("$caller") == "core:define#6" && $at == 6),if($is-params || isFnSeq_1($value) == fn.false_0() && $is-body == fn.false_0()) { return a.forEach_2($arg,function($_) /*fn.item_0()*/ {

n.eval_1(if($_ instance of String && fn.matches_2($_,"^\$")) { return {"name":"core:item","args":"$",fn.replace_3($_,"^\$","")}; } else {return $_;})

}); } else {return n.eval_1($arg);}; } else {return if($arg instance of Map) { return n.eval_1($arg); } else {return if($arg == ".") { return $frame("0"); } else {return if($arg == "$") { return $frame; } else {return if(fn.matches_2($arg,fn.concat_3("^\$[",$raddle:ncname,"]+$"))) { return $frame(fn.replace_3($arg,"^\$","")); } else {return if(fn.matches_2($arg,fn.concat_5("^[",$raddle:ncname,"]?:?[",$raddle:ncname,"]+#(\p{N}|N)+"))) { return resolveFunction_2($frame,$name); } else {return $arg;};};};};};}

})

};

function isFnSeq_1($value) /*Item*/ {

if(array.size_1($value) == 0) { return nil_0(); } else {return fn.distinctValues_1(array.flatten_1(array.forEach_2($value,function($_) /*fn.item_0()*/ {

if($_ instance of Map) { return isFnSeq_1($value); } else {return $_ instance of String && fn.matches_2($_,"^\.$|^\$$");}

}))) == fn.true_0();}

};

export function import_3($frame,$prefix,$uri) /*Item*/ {

return import * as $prefix from nil_0()

};

export function import_4($frame,$prefix,$uri,$location) /*Item*/ {

return let $import = new Item(if(fn.empty_1($location) || xmldb.getMimeType_2("AnyURI",($location)) == "application/xquery") { return n.import_1($location); } else {return let $src = new Item(util.binaryToString_1(util.binaryDoc_1($location))),n.eval_1(raddle.parse_2($src,$frame))($frame);})

};

export function module_4($frame,$prefix,$ns,$desc) /*Item*/ {

return map.new_1(($frame,{"$prefix":$prefix,"$uri":$ns,"$description":$desc,"$functions":{},"$exports":{}}))

}
