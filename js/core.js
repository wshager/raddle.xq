/* xquery version "3.1" */
/*module namespace core="http://raddle.org/core";
nil_0()*/
import * as raddle from "../content/raddle.xql"
import * as op from "op.xql"
import * as n from "n.xql"
import * as a from "array-util.xql"
import * as console from "http://exist-db.org/xquery/console"
export function element_3($frame,$name,$content) /*new n.Item()*/ {
return n.element_2($name,$content);
}
export function attribute_3($frame,$name,$content) /*new n.Item()*/ {
return n.attribute_2($name,$content);
}
export function text_2($frame,$content) /*new n.Item()*/ {
return n.text_1($content);
}
export function define_6($frame,$name,$desc,$args,$type,$body) /*new n.Item()*/ {
var $map,$pre,$_,$i;
return (($map = new n.Item(a.foldLeftAt_3($args,n.map(n.Sequence()),function($pre,$_1,$i) /*new n.Item()*/ {
return $_($frame);
})),
map.new_1(($frame,map.entry_2("$functions",n.map()),map.entry_2("$exports",map.put_4($frame("$exports"),fn.concat_3($name,"#",array.size_1($args)),(n.bind_3($body,$args,$type)($frame))))))));
}
export function describe_5($frame,$name,$desc,$args,$type) /*new n.Item()*/ {
return map.put_3($frame,fn.concat_3($name,"#",array.size_1($args)),n.map(n.Sequence("name",$name,"description",$desc)));
}
export function function_3($args,$type,$body) /*new n.Item()*/ {
return n.bind_3($body,$args,$type);
}
export function getNameSuffix_1($name) /*new n.Item()*/ {
var $cp;
return (($cp = new n.Item(fn.stringToCodepoints_1($name)),
(n.geq_2(n.filter_2($cp,n.Sequence(fn.last_0())),n.Sequence(42,43,45,63,95)) ? n.Sequence(fn.codepointsToString_1(fn.reverse_1(fn.tail_1(fn.reverse_1($cp)))),fn.codepointsToString_1(n.filter_2($cp,n.Sequence(fn.last_0())))) : n.Sequence($name,""))));
}
export function typegen1_2($type,$valtype) /*new n.Item()*/ {
return util.eval_1(fn.concat_4($type,"(",$valtype,")"));
}
export function typegen1_2($type,$seq) /*new n.Item()*/ {
return (($type == "array") ? n.array_1($seq) : nil_0());
}
export function typegen2_4($type,$keytype,$valtype,$body) /*new n.Item()*/ {
var $$valtype;
return (($type == "map") ? util.eval_1(fn.concat_3("map {",$body,"}")) : function($keytype) /*$valtype*/ {
return $body;
});
}
export function typegen2_3($type,$keytype,$valtype) /*new n.Item()*/ {
return util.eval_1(fn.concat_4($type,"(",$valtype,")"));
}
export function typegen2_2($type,$body) /*new n.Item()*/ {
return (($type == "map") ? util.eval_1(fn.concat_3("map {",$body,"}")) : nil_0());
}
export function typegen2_4($type,$keytype,$valtype,$body) /*new n.Item()*/ {
var $$valtype;
return (($type == "map") ? util.eval_1(fn.concat_3("map {",$body,"}")) : function($keytype) /*$valtype*/ {
return $body;
});
}
export function typegen_4($type,$frame,$name,$val) /*new n.Item()*/ {
return map.put_3($frame,$name,$val);
}
export function typegen_3($type,$frame,$name) /*new n.Item()*/ {
var $val,$i;
return (function($frame,$val,$i) /*new n.Item()*/ {
return (($val = new n.Item((fn.empty_1($val) ? $type : $val)),map.put_3($frame,(($name == "") ? fn.string_1($i) : $name),$val)));
});
}
export function eval_1($value) /*new n.Item()*/ {
var $name,$args,$s,$local,$isType,$isOp,$a;
return (($value instanceof n.array(new n.Item())) ? n.quoteSeq_1($value) : (($value instanceof Map) ? ($name = new n.Item($value("name")),$args = new n.Item($value("args")),$s = new n.Item(array.size_1($args)),(fn.matches_2($name,n.concat_2(n.concat_2("^core:[",raddle.ncname),"]+$")) ? ($local = new n.Item(fn.replace_3($name,"^core:","")),$isType = new n.Item(n.geq_2($local,map.keys_1(n.typemap))),$isOp = new n.Item(map.contains_2(n.operatorMap,$local)),$args = new n.Item((($isType || $isOp) ? array.insertBefore_3($args,1,$local) : $args)),$name = new n.Item(($isType ? ($a = new n.Item(n.typemap($local)),fn.concat_4("core:typegen",(n.ggt_2($a,0) ? $a : ""),"#",($s + 1))) : fn.concat_3($name,"#",$s))),n.quote_2($name,$args)) : ($name = new n.Item((($name == "") ? fn.concat_2("n:seq#",$s) : fn.concat_3($name,"#",$s))),n.quote_2($name,$args)))) : n.quote_1($value)));
}
export function apply_3($frame,$name,$args) /*new n.Item()*/ {
var $self,$f;
return (($self = new n.Item(isCurrentModule_2($frame,$name)),
$f = new n.Item(resolveFunction_3($frame,$name,$self)),
$frame = new n.Item(map.put_3($frame,"$callstack",array.append_2($frame("$callstack"),$name))),
$frame = new n.Item(map.put_3($frame,"$caller",$name)),
($self ? $f(processArgs_2($frame,$args)) : fn.apply_2($f,processArgs_2($frame,$args)))));
}
function isCurrentModule_2($frame,$name) /*new n.Item()*/ {
return (map.contains_2($frame,"$prefix") && fn.matches_2($name,fn.concat_3("^",$frame("$prefix"),":")));
}
export function resolveFunction_2($frame,$name) /*new n.Item()*/ {
return resolveFunction_3($frame,$name,$self);
}
export function resolveFunction_3($frame,$name,$self) /*new n.Item()*/ {
var $parts,$prefix,$module,$theirname;
return ($self ? ($frame("$exports")($name)) : ($parts = new n.Item(fn.tokenize_2($name,":")),$prefix = new n.Item((n.filterAt_2($parts,(n.geq_2($_0,2))) ? n.filterAt_2($parts,(n.geq_2($_0,1))) : "")),$module = new n.Item(($frame("$imports")($prefix))),$theirname = new n.Item(fn.concat_2(($module("$prefix") ? fn.concat_2($module("$prefix"),":") : ""),n.filter_2($parts,n.Sequence(fn.last_0())))),$module("$exports")($theirname)));
}
export function processArgs_2($frame,$args) /*new n.Item()*/ {
var $arg,$at,$isParams,$isBody,$_;
return (a.forEachAt_2($args,function($arg,$at) /*new n.Item()*/ {
var $isParams,$isBody,$_;
return (($arg instanceof n.array(new n.Item())) ? ($isParams = new n.Item((n.Sequence((($frame("$caller") == "core:define#6") && n.geq_2($at,4))) || n.Sequence((($frame("$caller") == "core:function#3") && n.geq_2($at,1))))),$isBody = new n.Item((($frame("$caller") == "core:define#6") && n.geq_2($at,6))),(($isParams || n.Sequence(n.geq_2((n.geq_2(isFnSeq_1($value),fn.false_0()) && $isBody),fn.false_0()))) ? a.forEach_2($arg,function($_3) /*new n.Item()*/ {
return n.eval_1(((($_ instanceof new n.String()) && fn.matches_2($_,"^\$")) ? n.map(n.Sequence("name","core:item","args",n.array(n.Sequence("$",fn.replace_3($_,"^\$",""))))) : $_));
}) : n.eval_1($arg))) : (($arg instanceof Map) ? (n.eval_1($arg)($frame)) : (($arg == ".") ? $frame("0") : (($arg == "$") ? $frame : (fn.matches_2($arg,fn.concat_3("^\$[",raddle.ncname,"]+$")) ? $frame(fn.replace_3($arg,"^\$","")) : (fn.matches_2($arg,fn.concat_5("^[",raddle.ncname,"]?:?[",raddle.ncname,"]+#(\p{N}|N)+")) ? resolveFunction_2($frame,$name) : $arg))))));
}));
}
function isFnSeq_1($value) /*new n.Item()*/ {
var $_;
return (((array.size_1($value) == 0) ? nil_0() : n.geq_2(fn.distinctValues_1(array.flatten_1(array.forEach_2($value,function($_1) /*new n.Item()*/ {
return (($_ instanceof Map) ? isFnSeq_1($value) : (($_ instanceof new n.String()) && fn.matches_2($_,"^\.$|^\$$")));
}))),fn.true_0())));
}
export function import_3($frame,$prefix,$uri) /*new n.Item()*/ {
return import_4($frame,$prefix,$ns);
}
export function import_4($frame,$prefix,$uri,$location) /*new n.Item()*/ {
var $import,$src;
return (($import = new n.Item(((fn.empty_1($location) || (xmldb.getMimeType_1(new n.AnyURI($location)) == "application/xquery")) ? n.import_1($location) : ($src = new n.Item(util.binaryToString_1(util.binaryDoc_1($location))),n.eval_1(raddle.parse_2($src,$frame))($frame)))),
map.put_3($frame,"imports",map.put_3($frame("imports"),$prefix,$core))));
}
export function module_4($frame,$prefix,$ns,$desc) /*new n.Item()*/ {
return map.new_1(($frame,n.map(n.Sequence("$prefix",$prefix,"$uri",$ns,"$description",$desc,"$functions",n.map(n.Sequence()),"$exports",n.map(n.Sequence())))));
}