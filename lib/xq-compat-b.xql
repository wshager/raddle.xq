xquery version "3.1";

module namespace xqc="http://raddle.org/xquery-compat";

import module namespace console="http://exist-db.org/xquery/console";
import module namespace a="http://raddle.org/array-util" at "../lib/array-util.xql";
import module namespace dawg="http://lagua.nl/dawg" at "../lib/dawg.xql";

(:
semicolon = 0
open := 1;
close := 2;
comma := 3;
reserved := 4;
var := 5;
qname := 6;
string := 7;
number := 8;
unknown := 9;
 :)

declare variable $xqc:ncform := "\p{L}\p{N}\-_";
declare variable $xqc:ncname := concat("^[",$xqc:ncform,"]");
declare variable $xqc:qform := concat("[",$xqc:ncform,"]*:?[",$xqc:ncform,"]+");
declare variable $xqc:qname := concat("^",$xqc:qform,"(#\p{N}+)?$");
declare variable $xqc:var-qname := concat("^\$",$xqc:qform,"$");
declare variable $xqc:operator-regexp := "=#\p{N}+=";

declare variable $xqc:operators as map(xs:integer, xs:string) := map {
	201: "some",
	202: "every",
	203: "switch",
	204: "typeswitch",
	205: "try",
	206: "if",
	207: "then",
	208: "else",
	209: "let",
	210: ":=",
	211: "return",
	212: "case",
	213: "default",
	214: "xquery",
	215: "version",
	216: "module",
	217: "declare",
	218: "variable",
	219: "import",
	220: "at",
	221: "for",
	222: "in",
	223: "where",
	224: "order-by",
	225: "group-by",
	300: "or",
	400: "and",
	501: "eq",
	502: "ne",
	503: "lt",
	504: "le",
	505: "gt",
	506: "ge",
	507: "=",
	508: "!=",
	509: "<=",
	510: ">=",
	511: "<<",
	512: ">>",
	513: "<",
	514: ">",
	515: "is",
	600: "||",
	700: "to",
	801: "-",
	802: "+",
	901: "mod",
	902: "idiv",
	903: "div",
	904: "*",
	1001: "union",
	1002: "|",
	1101: "intersect",
	1102: "except",
	1200: "instance-of",
	1300: "treat-as",
	1400: "castable-as",
	1500: "cast-as",
	1600: "=>",
	1701: "+",
	1702: "-",
	1800: "!",
	1901: "/",
	2003: "?",
	2101: "array",
	2102: "attribute",
	2103: "comment",
	2104: "document",
	2105: "element",
	2106: "function",
	2107: "map",
	2108: "namespace",
	2109: "processing-instruction",
	2110: "text",
	2201: "array",
	2202: "attribute",
	2203: "comment",
	2204: "document-node",
	2205: "element",
	2206: "empty-sequence",
	2207: "function",
	2208: "item",
	2209: "map",
	2210: "namespace-node",
	2211: "node",
	2212: "processing-instruction",
	2213: "schema-attribute",
	2214: "schema-element",
	2215: "text",
	2400: "as",
	2501: "(:",
	2502: ":)",
	2005: ":"
};

declare variable $xqc:constructors := map {
    2101: "l",
	2102: "a",
	2103: "c",
	2104: "d",
	2105: "e",
	2106: "q",
	2107: "m",
	2108: "s",
	2109: "p",
	2110: "x"
};

declare variable $xqc:occurrence := map {
    2003: "zero-or-one",
    904: "zero-or-more",
    802: "one-or-more"
};

(: TODO increase / decrease depth, comma depth stays same:)
declare variable $xqc:block-chars := "\[\]\{\}\(\),";
declare variable $xqc:block-regex := concat("^[",$xqc:block-chars,"]$");
declare variable $xqc:blocks-regex := concat("^[",$xqc:block-chars,"]+$");
declare variable $xqc:stop-chars := "+=<>\*\?!/\|";
declare variable $xqc:stop-regex := concat("[",$xqc:block-chars,$xqc:stop-chars,"\$%]");
declare variable $xqc:block-around-re := concat("^[",$xqc:block-chars,"]|[",$xqc:block-chars,"]$");

declare variable $xqc:types := (
	"untypedAtomic",
	"dateTime",
	"dateTimeStamp",
	"date",
	"time",
	"duration",
	"yearMonthDuration",
	"dayTimeDuration",
	"float",
	"double",
	"decimal",
	"integer",
	"nonPositiveInteger",
	"negativeInteger",
	"long",
	"int",
	"short",
	"byte",
	"nonNegativeInteger",
	"unsignedLong",
	"unsignedInt",
	"unsignedShort",
	"unsignedByte",
	"positiveInteger",
	"gYearMonth",
	"gYear",
	"gMonthDay",
	"gDay",
	"gMonth",
	"string",
	"normalizedString",
	"token",
	"language",
	"NMTOKEN",
	"Name",
	"NCName",
	"ID",
	"IDREF",
	"ENTITY",
	"boolean",
	"base64Binary",
	"hexBinary",
	"anyURI",
	"QName",
	"NOTATION"
);

declare variable $xqc:operator-map as map(xs:integer, xs:string) := map {
	206: "if",
	209: "item",
	501: "eq",
	502: "ne",
	503: "lt",
	504: "le",
	505: "gt",
	506: "ge",
	507: "geq",
	508: "gne",
	509: "gle",
	510: "gge",
	511: "precedes",
	512: "follows",
	513: "glt",
	514: "ggt",
	600: "concat",
	801: "subtract",
	802: "add",
	904: "multiply",
	1002: "union",
	1701: "plus",
	1702: "minus",
	1800: "x-for-each",
	1901: "select",
(:	1902: "select-deep",:)
	2001: "x-filter",
	2003: "lookup",
	2004: "array",
	2005: "pair",
	2501: "comment"
};

declare variable $xqc:operator-trie := json-doc("/db/apps/raddle.xq/operator-trie.json");

(:
: TODO have these functions return functions...
declare variable $xqc:fns := ("position","last","name","node-name","nilled","string","data","base-uri","document-uri","number","string-length","normalize-space");
:)

declare variable $xqc:uri-chars := map {
    "%3E" : ">",
    "%3C" : "<",
    "%2C" : ",",
    "%3A" : ":"
};

declare function xqc:inspect-buf($s){
    if($s eq "") then
        ()
    else if(matches($s,"^;$")) then
        map { "t" : 0, "v" : $s}
    else if(matches($s,"^[\(\[\{]$")) then
        map { "t" : 1, "v" : $s}
    else if(matches($s,"^[\)\]\}]$")) then
        map { "t" : 2, "v" : $s}
    else if(matches($s,"^,$")) then
        map { "t" : 3, "v" : $s}
    else if(matches($s,$xqc:var-qname)) then
        map { "t" : 5, "v" : $s}
    else if(matches($s,"^%\p{N}+%$")) then
        map { "t" : 7, "v" : $s}
    else
        let $ret := dawg:traverse([$xqc:operator-trie,[]],$s)
        return if(empty($ret) or $ret instance of array(*)) then
            if(matches($s,"^\p{N}+$")) then
                map { "t" : 8, "v" : $s}
            else if(matches($s,$xqc:qname)) then
                map { "t" : 6, "v" : $s}
            else
                (: typically an unmatched : in maps OR qname :)
                (: TODO perform partial analysis, because it may contain a qname :)
                if(matches($s,":")) then
                    analyze-string($s,":")//text() ! xqc:inspect-buf(.)
                else if(matches($s,"^\-")) then
                    analyze-string($s,"\-")//text() ! xqc:inspect-buf(.)
                else if($s eq "$") then
                    (: for rdl :)
                    map { "t" : 10, "v" : $s}
                else
                    map { "t" : 9, "v" : $s}
        else
            map { "t" : 4, "v" : $ret}
};

declare function xqc:incr($a){
    array:for-each($a,function($entry){
        map:put($entry,"d",map:get($entry,"d") + 1)
    })
};

declare function xqc:tpl($t,$d,$v){
    map { "t": $t, "d": $d, "v": $v }
};

declare function xqc:op-name($v){
    if(map:contains($xqc:operator-map,$v)) then
        $xqc:operator-map($v)
    else
        $xqc:operators($v)
};

declare function xqc:unwrap($cur,$r,$d,$o,$i,$p){
    (: TODO cleanup (e.g. separate is-close and is-op), apply for all cases :)
    let $osize := array:size($o)
    let $size := array:size($r)
    let $ocur := if($osize gt 0) then $o($osize) else map {}
    let $ot := $ocur("t")
    let $ov := $ocur("v")
    let $has-op := $ot eq 4
    let $t := $cur("t")
    let $v := $cur("v")
    let $is-close := $t eq 2
    let $is-curly-close := $is-close and $v eq "}"
    let $is-paren-close := $is-close and $v eq ")"
    let $is-square-close := $is-close and $v eq "]"
    let $is-op := $is-close eq false() and $t eq 4
    let $is-else := $is-op and $v eq 208
    let $has-then := $has-op and $ov eq 207
    let $is-return := $is-op and $v eq 211
    let $is-let := $is-op and $v eq 209
    (: TODO only is let if at same depth! :)
    let $has-ass := ($is-let or $is-return) and $has-op and $ov eq 210
    let $has-xfor := $has-op and $ov eq 221
    let $is-x := $is-op and $v = (222,223,224,225)
    let $has-x := $has-op and $ov = (222,223,224,225)
    let $is-xlet := $is-let and $has-x
    let $is-body := $is-curly-close and $has-op and $ov eq 3106
    (: closing a constructor is always detected, because the opening bracket is never added to openers for constructors :)
    let $has-constr := $is-curly-close and $has-op and $ov gt 3000 and $ov lt 3100
    let $has-typesig := $has-op and $ov eq 2400
    (: has-params means there's no type-sig to close :)
    let $has-params := $is-paren-close and $has-op and $ov eq 3006
    let $has-else := $has-op and $ov eq 208
    let $has-open := $ot eq 1
    let $has-paren-open := $has-open and $ov eq "("
    let $has-curly-open := $has-open and $ov eq "{"
    let $has-square-open := $has-open and $ov eq "["
    let $has-ret := $has-op and $ov eq 211
    let $has-xret := $is-let eq false() and $has-ret
    let $has-tuple := $has-op and $ov eq 2005
    let $pass := $is-let and ($has-then or $has-op eq false() or $ov eq 3106 or $has-ret)
    let $has-direct-elem := $ot eq 12
    let $has-af := $is-square-close and $has-op and $ov = (2001,2004)
    let $has-xass := $has-op and $ov eq 210 and ($is-x or ($has-ass and $osize gt 1 and $o($osize - 1)("t") eq 4 and $o($osize - 1)("v") = (222,223,224,225)))
    let $is-xret := $is-return and ($has-x or $has-xass)
    let $matching := $is-close and $has-open and (
        ($is-curly-close and $has-curly-open) or
        ($is-paren-close and $has-paren-open) or
        ($is-square-close and $has-square-open))
    let $close-then := $is-else and $has-then
(:    let $nu := if($is-paren-close) then console:log(("has-params: ",$has-params,", is-type: ",$has-typesig," has-else: ",$has-else)) else ():)
    (: else adds a closing bracket :)
    let $nu := console:log(("v: ",$v," i: ",$i,", unwrap: ",$d, ", ocur: ",$ocur, ", has-params: ", $has-params, ", has-ass: ", $has-ass, ", is-body: ", $is-body, ", pass: ",$pass, ", is-x: ",$is-x, ", has-x: ",$has-x,", xfor:",$has-xfor, ", has-xass: ", $has-xass, ", has-xret: ",$has-xret, ", has-constr: ",$has-constr))
    let $r := if($has-else) then array:append($r,xqc:tpl(2,$d,"}")) else $r
    let $d := if($has-else) then $d - 1 else $d
    return
        if($osize eq 0 or $pass or $has-ass or $is-body or $has-typesig or $has-params or $has-af or $matching or $close-then or $is-xret or $has-xret or $is-x or $has-x or $has-xfor or $has-constr or $has-tuple or $has-direct-elem) then
(:            let $nu := console:log("stop"):)
            let $tpl :=
                if($has-x or $has-xass) then
                    (xqc:tpl(1,$d,"}"),xqc:tpl(2,$d - 1,")"),xqc:tpl(3,$d - 2,","))
                else
                    ()
            let $d := 
                if($has-x or $has-xass) then
                    $d - 2
                else
                    $d
            let $tpl :=
                if($has-tuple) then
                    xqc:tpl(2,$d,")")
                else if($has-params) then
                    (xqc:tpl(4,$d,"item"),xqc:tpl(1,$d,"("),xqc:tpl(2,$d,")"),$cur)
                else if($is-xret or $is-x or $is-xlet) then
                    let $tpl := ($tpl,xqc:tpl(4,$d,concat("x-",$xqc:operators($v))),xqc:tpl(1,$d,"("),xqc:tpl(1,$d+1,"{"))
                    let $d := $d + 2
                    return 
                        if($v eq 222) then
                            $tpl
                        else
                            a:fold-left-at($p,$tpl,function($pre,$cur,$i) {
                                $pre,
                                xqc:tpl(10,$d,"$"),
                                xqc:tpl(1,$d,"("),
                                xqc:tpl(4,$d+1,$cur),
                                xqc:tpl(3,$d+1,","),
                                xqc:tpl(4,$d+1,"$"),
                                xqc:tpl(1,$d+1,"("),
                                xqc:tpl(8,$d+2,$i),
                                xqc:tpl(2,$d+1,")"),
                                xqc:tpl(2,$d,")"),
                                if($is-let) then () else xqc:tpl(3,$d,",")
                            })
                else if($has-xret) then
                    (xqc:tpl(2,$d,"}"),xqc:tpl(2,$d - 1,")"),xqc:tpl(2,$d - 2,")"))
                else if($is-x and $has-x) then
                    ($tpl,xqc:tpl(3,$d,","))
                else if($is-body or $has-constr) then
                    (xqc:tpl($t,$d,$v),xqc:tpl($t,$d - 1,")"))
                else if($has-af or $is-close) then
                    let $close-curly :=
                        if($has-curly-open) then
                            if($osize gt 1) then
                                $o($osize - 1)("t") ne 4
                            else
                                true()
                        else
                            false()
                    return xqc:tpl($t,$d,if($close-curly) then $v else ")")
                else if($pass or $close-then or $has-xfor) then
                    ()
                else if($has-ass or $has-direct-elem) then
                    if($is-let and $r($size)("t") eq 3) then
                        ()
                    else
                        (xqc:tpl(2,$d,")"),xqc:tpl(3,$d - 1,","))
                else if($is-let) then
                    ()
                else
                    xqc:tpl($t,$d,$v)
            let $o :=
                if($has-typesig) then
                    a:pop(a:pop($o))
                else if($has-params or $has-constr or ($has-ass and $r($size)("t") ne 3) or $is-body or $has-af or $matching or $close-then or $is-xret or $is-x) then
                    a:pop($o)
                else
                    $o
            let $o :=
                if($has-params or $has-typesig) then
                    array:append($o,xqc:tpl(4,$d,3106))
                else if($is-xret or $is-x) then
                    array:append($o,xqc:tpl($t,$d,$v))
                else
                    $o
            return
                map {
                    "r": if(exists($tpl)) then fold-left($tpl,$r,array:append#2) else $r,
                    "d": 
                        if($is-body or $has-xret or $has-constr) then 
                            $d - 2
                        else if($is-xret) then
                            $d + 1
                        else if ($is-x or $is-xlet) then
                            $d + 2
                        else if($has-ass or $has-typesig or $has-params or $has-af or $matching) then
                            $d - 1
                        else $d,
                    "o": $o,
                    "i": if($pass) then $i else map:put($i, $d, array:size($r)),
                    "p": if($has-xret) then [] else $p
                }
        else
(:            let $nu := console:log("auto"):)
(:            return:)
            xqc:unwrap($cur, if($has-op and $ov gt 3000) then $r else array:append($r,xqc:tpl(2,$d,")")), $d - 1, a:pop($o), map:put($i, $d, array:size($r)),$p)
};


declare function xqc:rtp($r,$d,$o,$i,$p) {
    xqc:rtp($r,$d,$o,$i,$p,())
};

declare function xqc:rtp($r,$d,$o,$i,$p,$tpl) {
    xqc:rtp($r,$d,$o,$i,$p,$tpl,false())
};

declare function xqc:rtp($r,$d,$o,$i,$p,$tpl,$remove-op) {
    xqc:rtp($r,$d,$o,$i,$p,$tpl,$remove-op,())
};

declare function xqc:rtp($r,$d,$o,$i,$p,$tpl,$remove-op,$new-op) {
    xqc:rtp($r,$d,$o,$i,$p,$tpl,$remove-op,$new-op,())
};

declare function xqc:rtp($r as array(*),$d as xs:integer,$o as array(*),$i as map(*),$p as array(*),$tpl as map(*)*,$remove-op as xs:boolean?,$new-op as map(*)?, $param as xs:string?) {
    if($remove-op) then
        let $ocur :=
            let $osize := array:size($o)
            return
                if($osize gt 0) then
                    $o($osize)
                else
                    map {}
        let $o := a:pop($o)
        return
            map {
                "d": $d,
                "o": if(exists($new-op)) then array:append($o, $new-op) else $o,
                "i": if(exists($tpl)) then map:put($i, $tpl[1]("d"), array:size($r) + 1) else $i,
                "r": if(exists($tpl)) then fold-left($tpl,$r,array:append#2) else $r,
                "p": if($param) then array:append($p,$param) else $p
            }
    else
            map {
                "d": $d,
                "o": if(exists($new-op)) then array:append($o, $new-op) else $o,
                "i": if(exists($tpl)) then map:put($i, $tpl[1]("d"), array:size($r) + 1) else $i,
                "r": if(exists($tpl)) then fold-left($tpl,$r,array:append#2) else $r,
                "p": if($param) then array:append($p,$param) else $p
            }
};

(:
 : Process:
 : - denote depth: increase/decrease for opener/closer
 : - never look ahead, only denote open operators
 : - only append what is processed!
 : - detect operator: binary or unary
 : - detect + transform namespace declarations: if *at* is found, stack it to o, remove last paren and write out comma
 : - transform operator to prefix notation
 :)

declare function xqc:process($cur as map(*), $ret as array(*), $d as xs:integer, $o as array(*), $i as map(*), $p as array(*)){
        let $nu := console:log(("cur: ",$cur))
        let $size := array:size($ret)
        let $t := $cur("t")
        let $v := $cur("v")
        let $osize := array:size($o)
        let $ocur := if($osize gt 0) then $o($osize) else map {}
        let $has-op := $ocur("t") eq 4
        let $has-pre-op := $has-op and $ocur("v") >= 300 and $ocur("v") < 2100
        return
            if($has-op and $ocur("v") eq 2501) then
                if($t eq 4 and $v eq 2502) then
                    xqc:rtp($ret,$d,$o,$i,$p,xqc:tpl(2,$d,")"),true())
                else
                    let $tpl := $ret($size)
                    return xqc:rtp(a:put($ret,$size,xqc:tpl(7,$tpl("d"),concat($tpl("v")," ",$v))),$d,$o,$i,$p)
            else if($t eq 0) then
                xqc:unwrap($cur,$ret,$d,$o,$i,$p)
            else if($t eq 1) then
                if($v eq "[") then
                    let $cur := xqc:tpl($t,$d,$v)
                    (: TODO pull in right-side if filter, except when select :)
                    let $has-select := $has-op and $ocur("v") eq 1901
                    let $it := if($size eq 0 or ($ret($size)("t") = (1,3,6) and $has-select eq false())) then 2004 else 2001
                    let $cur := xqc:tpl(4,$d,xqc:op-name($it))
                    let $ret :=
                        if($it eq 2001 and $has-select eq false()) then
                            let $split := $i($d)
(:                            let $split := if($ret($split)("t") eq 1) then $split - 1 else $split:)
                            let $left := xqc:incr(array:subarray($ret,$split))
                            let $ret := array:subarray($ret,1,$split - 1)
                            return array:join(($ret,[$cur,xqc:tpl(1,$d,"(")],$left))
                        else
                            $ret
                    let $tpl :=
                        if($it eq 2001) then
                            if($has-select) then
                                (xqc:tpl(3,$d,","),$cur,xqc:tpl(1,$d,"("))
                            else
                                xqc:tpl(3,$d,",")
                        else
                            ($cur,xqc:tpl(1,$d,"("))
                    return xqc:rtp($ret,$d + 1,$o,$i,$p,$tpl,false(),xqc:tpl(4,$d,$it))
                else if($v eq "{") then
                    let $has-rettype := $has-op and $ocur("v") = 2400
                    let $o :=
                        if($has-rettype) then
                            array:remove($o,$osize)
                        else
                            $o
                    let $ocur :=
                        if($has-rettype) then
                            $o($osize - 1)
                        else
                            $ocur
                    let $has-params := $has-op and $ocur("v") eq 3106
                    (: don't treat function as constructor here :)
                    let $has-constr-type := $has-params eq false() and $has-op and $ocur("v") gt 3000 and $ocur("v") lt 3100
    (:                let $nu := console:log(($d,", has-params: ",$has-params,", has-rettype: ",$has-rettype)):)
                    let $cur := xqc:tpl($t,$d,$v)
                    let $tpl :=
                        if($has-params) then
                            let $tpl :=
                                if($has-rettype) then
                                    xqc:tpl(2,$d,")")
                                else
                                    (xqc:tpl(3,$d,","),xqc:tpl(4,$d,"item"),xqc:tpl(1,$d,"("),xqc:tpl(2,$d,")"),xqc:tpl(2,$d,")"))
                            return
                                a:fold-left-at($p,($tpl,xqc:tpl(3,$d - 1,","),$cur),function($pre,$cur,$i) {
                                    ($pre,xqc:tpl(10,$d,"$"),xqc:tpl(1,$d,"("),xqc:tpl(7,$d+1,$cur),xqc:tpl(3,$d+1,","),xqc:tpl(10,$d+1,"$"),xqc:tpl(1,$d,"("),xqc:tpl(8,$d,string($i)),xqc:tpl(2,$d,")"),xqc:tpl(2,$d,")"),xqc:tpl(3,$d,","))
                                })
                        else if($has-constr-type) then
                            $cur
                        else if($has-op) then
                            xqc:tpl($t,$d,"(")
                        else
                            $cur
                    return
                        (: remove constr type if not constr :)
                        xqc:rtp($ret,if($has-params) then $d else $d + 1,$o,$i,if($has-params) then [] else $p,$tpl,$has-constr-type,if($has-params) then () else if($has-constr-type) then $ocur else $cur)
                else
                    (: detect first opening bracket after function declaration :)
                    (: detect parameters, we need to change 2106 to something else at opening bracket here :)
                    let $has-func := $has-op and $ocur("v") eq 2106
                    let $has-constr-type := $has-func eq false() and $has-op and $ocur("v") gt 2100 and $ocur("v") lt 2200
                    let $cur := xqc:tpl($t,$d + 1,$v)
                    let $last := if($size) then $ret($size) else map {}
                    let $has-lambda := $has-func and $last("t") eq 4
                    let $ret :=
                        if($has-lambda) then
                            a:pop($ret)
                        else
                            $ret
                    let $tpl :=
                        if($has-func) then
                            let $tpl := (xqc:tpl(4,$d,"function"),$cur,xqc:tpl(4,$d,""),xqc:tpl($t,$d + 1,$v))
                            return
                                if($has-lambda) then
                                    (xqc:tpl(4,$d,"quote-typed"),$cur,$tpl)
                                else
                                    (xqc:tpl(3,$d,","),$tpl)
                        else if($size eq 0 or $ret($size)("t") = (1,3)) then
                            (xqc:tpl(4,$d,""),$cur)
                        else
                            $cur
                    return
                        (: remove constr type if not constr :)
                        xqc:rtp($ret,if($has-func) then $d + 2 else $d + 1,$o,$i,$p,$tpl,
                            $has-func or $has-constr-type,
                            if($has-func) then xqc:tpl(4,$d,3006) else $cur)
            else if($t eq 2) then
                xqc:unwrap(xqc:tpl($t,$d,$v), $ret, $d, $o, $i, $p)
            else if($t eq 3) then
                (: some things to detect here:
                 * param
                 * assignment
                :)
                (:
                if it's a param, it means type wasn't set, so add item
                :)
                if($has-op and $ocur("v") eq 2005) then
                    let $tmp := xqc:unwrap(xqc:tpl(4,$d,209), $ret, $d, $o, $i, $p)
                    return xqc:rtp($tmp("r"), $tmp("d"), $tmp("o"), $tmp("i"),$tmp("p"), xqc:tpl($t,$d,$v))
                else if($has-op and $ocur("v") eq 210) then
                    let $tmp := xqc:unwrap(xqc:tpl(4,$d,209), $ret, $d, $o, $i, $p)
                    let $d := $tmp("d")
                    return xqc:rtp($tmp("r"), $d + 1, $tmp("o"), $tmp("i"),$tmp("p"), (xqc:tpl(10,$d,"$"),xqc:tpl(1,$d,"(")), (),xqc:tpl(4,$d,209))
                else
                    let $cur := xqc:tpl($t,$d,$v)
                    let $has-typesig := $has-op and $ocur("v") eq 2400
                    let $tpl :=
                        if($has-typesig) then
                            $cur
                        else if($has-op and $ocur("v") eq 3006) then
                            (xqc:tpl(4,$d,"item"),xqc:tpl(1,$d,"("),xqc:tpl(2,$d,")"),$cur)
                        else
                            $cur
                    return xqc:rtp($ret,$d,$o,$i,$p,$tpl,$has-typesig)
            else if($t eq 4) then
                if($v eq 217) then
                    xqc:rtp($ret,$d,$o,$i,$p,(),(),xqc:tpl($t,$d,$v))
                else if($v eq 218) then
                    (: TODO check if o contains declare (would it not?) :)
                    xqc:rtp($ret,$d + 1, $o, $i,$p, (xqc:tpl(10,$d,"$>"),xqc:tpl(1,$d,"(")),$has-op and $ocur("v") eq 217,xqc:tpl($t,$d,$v))
                else if($v eq 216) then
                    if($has-op and $ocur("v") eq 219) then
                        xqc:rtp(a:pop($ret),$d,$o,$i,$p,(xqc:tpl($t,$d,"$<"),xqc:tpl(1,$d,"(")),true(),xqc:tpl($t,$d,$v))
                    else
                        xqc:rtp($ret,$d + 1,$o,$i,$p,(xqc:tpl($t,$d,"$*"),xqc:tpl(1,$d,"(")),$has-pre-op)
                else if($v eq 215) then
                    xqc:rtp($ret,$d,$o,$i,$p,(xqc:tpl(4,$d,"xq-version"),xqc:tpl(1,$d,"(")),$has-op,xqc:tpl($t,$d,$v))
                else if($v = (214,2108)) then
                    xqc:rtp($ret,$d,$o,$i,$p,(),$has-op,xqc:tpl($t,$d,$v))
                else if($v eq 219) then
                    xqc:rtp($ret,$d,$o,$i,$p,xqc:tpl($t,$d,xqc:op-name($v)),$has-pre-op,xqc:tpl($t,$d,$v))
                else if($v eq 2106 and $has-op and $ocur("v") eq 217) then
                    (: check if o contains declare, otherwise it's anonymous :)
                    xqc:rtp($ret,$d + 1, $o, $i,$p, (xqc:tpl(10,$d,"$>"),xqc:tpl(1,$d,"(")),$has-op and $ocur("v") eq 217,xqc:tpl($t,$d,$v))
                else if($v eq 2400) then
                    let $has-params := $has-op and $ocur("v") eq 3006
                    return xqc:rtp($ret,$d, $o, $i,$p, if($has-params) then () else xqc:tpl(3,$d,","), (), xqc:tpl($t,$d,$v))
                else if($v eq 207) then
                    xqc:rtp(a:pop($ret),$d + 2,$o,$i,$p,(xqc:tpl(3,$d + 1,","),xqc:tpl(1,$d + 1,"{")),false(),xqc:tpl($t,$d,$v))
                else if($v eq 208) then
                    let $tmp := xqc:unwrap(xqc:tpl($t,$d,$v), $ret, $d, $o, $i, $p)
                    let $d := $tmp("d")
                    return xqc:rtp($tmp("r"),$d,$tmp("o"),$tmp("i"),$tmp("p"),(xqc:tpl(2,$d,"}"),xqc:tpl(3,$d - 1,","),xqc:tpl(1,$d - 1,"{")),false(),xqc:tpl($t,$d,$v))
                else if($v eq 209) then
                    (: TODO check if o contains something that prevents creating a new let-ret-seq :)
                    (: remove entry :)
                    let $has-x := $has-op and $ocur("v") = (222,223,224,225)
                    let $tmp := xqc:unwrap(xqc:tpl($t,$d,$v), $ret, $d, $o, $i, $p)
                    let $d := $tmp("d")
                    let $o := $tmp("o")
                    (: wrap inner let :)
                    let $open := if($has-op and $ocur("v") eq 210) then xqc:tpl(1,$d,"(") else ()
                    let $o := if(exists($open)) then array:append($o,xqc:tpl(1,$d,"(")) else $o
                    return xqc:rtp($tmp("r"),$d + 2, $o, $tmp("i"),$tmp("p"), if($has-x) then () else ($open,xqc:tpl(10,$d + 1,"$"),xqc:tpl(1,$d + 1,"(")),(),xqc:tpl($t,$d,$v))
                else if($v eq 210) then
                    (: remove let, variable or comma from o :)
                    xqc:rtp($ret,$d,$o,$i,$p,xqc:tpl(3,$d,","),$has-op and $ocur("v") = (218, 209),xqc:tpl($t,$d,$v))
                else if($v eq 211) then
                    (: close anything that needs to be closed in $o:)
                    xqc:unwrap(xqc:tpl($t,$d,$v),$ret,$d,$o,$i,$p)
                else if($v eq 220) then
                    (: close anything that needs to be closed in $o:)
                    xqc:rtp($ret,$d,$o,$i,$p,xqc:tpl(3,$d,","))
                else if($v eq 221) then
                    (: start x-for, add var to params :)
                    if($has-op and $ocur("v") eq 222) then
                        xqc:rtp($ret,$d,$o,$i,$p,(xqc:tpl(1,$d,"}"),xqc:tpl(2,$d,")"),xqc:tpl(3,$d,",")),(),xqc:tpl($t,$d,$v))
                    else
                        xqc:rtp($ret,$d + 1,$o,$i,$p,(xqc:tpl(4,$d,"x-for"),xqc:tpl(1,$d,"(")),(),xqc:tpl($t,$d,$v))
                else if($v = (222,223,224,225)) then
                    (: x-in/x-where/x-orderby/x-groupby, remove x-... from o :)
                    xqc:unwrap(xqc:tpl($t,$d,$v),$ret,$d,$o,$i,$p)
                else if($v eq 507) then
                    xqc:rtp($ret,$d,$o,$i,$p,xqc:tpl(3,$d,","),$has-pre-op,xqc:tpl($t,$d,$v))
                else if($v ge 300 and $v lt 2100) then
                    if($size eq 0) then
                        (: nothing before, so op must be unary :)
(:                        let $nu := console:log(("un-op: ",$v)):)
                        (: unary-op: insert op + parens :)
                        let $v := $v + 900
                        return xqc:rtp($ret,$d + 1, $o, $i,$p, (xqc:tpl($t,$d,xqc:op-name($v)),xqc:tpl(1,$d,"(")),(),xqc:tpl($t,$d,$v))
                    else
                        let $prev := $ret($size)
(:                        let $tmp := if($v eq 1901) then xqc:unwrap(xqc:tpl($t,$d,$v),$ret,$d,$o,$i,$p) else map {:)
(:                            "r": $ret,:)
(:                            "d": $d,:)
(:                            "o": $o,:)
(:                            "i": $i,:)
(:                            "p": $p:)
(:                        }:)
(:                        let $ret := $tmp("r"):)
(:                        let $d := $tmp("d"):)
(:                        let $o := $tmp("o"):)
(:                        let $i := $tmp("i"):)
(:                        let $p := $tmp("p"):)
                        return
                            if(($v eq 904 and $ocur("t") eq 1) or ($v = (802,904,2003) and $has-op and $ocur("v") eq 2400)) then
                                (: these operators are occurrence indicators when the previous is an open paren or qname :)
                                (: when the previous is a closed paren, it depends what the next will be :)
                                if($has-op) then
                                    let $split := $i($d)
                                    let $left := array:subarray($ret,1,$split - 1)
                                    let $right := array:subarray($ret,$split)
                                    return xqc:rtp($left,$d,$o,$i,$p,(
                                        xqc:tpl($t,$d,"occurs"),
                                        xqc:tpl(1,$d,"("),
                                        array:flatten(xqc:incr($right)),
                                        xqc:tpl(3,$d,","),
                                        xqc:tpl($t,$d + 1,$xqc:occurrence($v)),
                                        xqc:tpl(1,$d + 1,"("),
                                        xqc:tpl(2,$d + 1,")"),
                                        xqc:tpl(2,$d,")")
                                    ))
                                else
                                    xqc:rtp($ret,$d,$o,$i,$p,xqc:tpl(7,$d,$xqc:operators($v)))
                            else if($v = (801,802) and $prev("t") = (1,3,4)) then
                                let $v := $v + 900
                                return xqc:rtp($ret,$d + 1, $o, $i,$p, (xqc:tpl($t,$d,xqc:op-name($v)),xqc:tpl(1,$d,"(")), (), xqc:tpl($t,$d,$v))
                            else
                                (: bin-op: pull in left side, add parens :)
                                let $preceding-op := if($has-pre-op and $ocur("v")) then $ocur("v") ne 2005 and $ocur("v") ge $v else false()
(:                                let $nu := console:log(("bin-op: ",$v,", prec: ",$ocur," d: ",$d,", i: ", $i)):)
                                (: if preceding, lower depth, as to take the previous index :)
                                (: furthermore, close directly and remove the operator :)
                                let $d :=
                                    if($preceding-op) then
                                        $d - 1
                                    else
                                        $d
                                let $split := if(map:contains($i,$d)) then $i($d) else 1
(:                                let $nu := console:log($split):)
(:                                let $split := if($ret($split)("t") eq 1) then $split - 1 else $split:)
                                let $left :=
(:                                    if($v eq 1901 and $has-op and $ocur("v") eq 1901) then:)
(:                                        []:)
(:                                    else :)
                                    if($preceding-op) then
                                        array:append(xqc:incr(array:subarray($ret,$split)),xqc:tpl(2,$d + 1,")"))
                                    else
                                        xqc:incr(array:subarray($ret,$split))
(:                                let $nu := console:log($left):)
                                let $o :=
                                    if($preceding-op) then
                                        array:remove($o,$osize)
                                    else
                                        $o
                                let $ret := array:append(array:subarray($ret,1,$split - 1),xqc:tpl($t,$d,xqc:op-name($v)))
                                let $i := if($preceding-op) then map:put($i, $d, $split) else map:put($i, $d, array:size($ret))
(:                                let $ret := array:join((array:append($ret,xqc:tpl(1,$d,"(")),$left)):)
                                return xqc:rtp($ret,$d + 1, $o, $i,$p, (xqc:tpl(1,$d+1,"("),array:flatten($left),xqc:tpl(3,$d + 1,",")), (), xqc:tpl($t,$d,$v))
                    else if($v gt 2100 and $v lt 2200) then
                        xqc:rtp($ret,$d,$o,$i,$p,xqc:tpl($t,$d,xqc:op-name($v)),$has-pre-op,xqc:tpl($t,$d,$v))
                    else
                        xqc:rtp($ret,$d,$o,$i,$p,xqc:tpl($t,$d,xqc:op-name($v)),$has-pre-op)
            else if($t eq 5) then
                if(matches($v,"^\$")) then
                    let $is-param := $has-op and $ocur("v") eq 3006
                    let $is-for := $has-op and $ocur("v") eq 221
                    let $has-ass := $has-op and $ocur("v") = (218,209)
                    let $has-xass := $has-ass and $osize gt 1 and $o($osize - 1)("t") eq 4 and $o($osize - 1)("v") = (222,223,224,225)
                    let $v := replace($v,"^\$","")
                    let $tpl :=
                        if($is-param or $is-for or $has-xass) then
                            ()
                        else if($has-ass) then
                            xqc:tpl($t,$d,$v)
                        else
                            (xqc:tpl(10,$d,"$"),xqc:tpl(1,$d,"("),xqc:tpl($t,$d + 1,$v),xqc:tpl(2,$d,")"))
                    return xqc:rtp($ret,$d,$o,$i,$p,$tpl,(),(),if($is-param or $is-for or $has-xass) then $v else ())
                else
                    xqc:rtp($ret,$d,$o,$i,$p,xqc:tpl($t,$d,$v))
            else if($t eq 6) then
                if($has-op and $ocur("v") = (2102,2105)) then
(:                let $nu := console:log(map {"auto-constr":$ocur,"i":$i}) return:)
                    let $tmp := xqc:rtp(a:pop($ret),$d + 1,$o,$i,$p,(xqc:tpl(4,$ocur("d"),$xqc:constructors($ocur("v"))),xqc:tpl(1,$d,"("),xqc:tpl(1,$d+1,"{"),xqc:tpl(7,$d + 2,$v),xqc:tpl(2,$d + 2,"}"),xqc:tpl(3,$d + 1,",")),true(),xqc:tpl(4,$ocur("d"),$ocur("v") + 900))
                    return map:put($tmp,"i",$i)
                else if($has-op and $ocur("v") eq 2106) then
                    xqc:rtp($ret,$d,$o,$i,$p,xqc:tpl(7,$d,$v))
                else if($has-op and $ocur("v") eq 2108) then
                    (: namespace binding :)
                    xqc:rtp($ret,$d,$o,$i,$p,xqc:tpl(7,$d,$v),true())
                else
                    xqc:rtp($ret,$d,$o,$i,$p,xqc:tpl($t,$d,$v))
            else if($t eq 12) then
                xqc:rtp($ret,$d + 1,$o,$i,$p,(xqc:tpl(4,$d,"e"),xqc:tpl(1,$d,"("),xqc:tpl(7,$d + 1,$v),xqc:tpl(3,$d + 1,",")),(),xqc:tpl($t,$d,$v))
            else
                xqc:rtp($ret,$d,$o,$i,$p,xqc:tpl($t,$d,$v))
};

declare variable $xqc:token-re := concat("([%\p{N}\p{L}",$xqc:block-chars,"]?)([",$xqc:block-chars,"]|[",$xqc:stop-chars,"]+)([\$%\p{N}\p{L}",$xqc:block-chars,"]?)");

declare function xqc:prepare-tokens($part){
    if(empty($part) or matches($part,"^\s*$")) then
        ()
    else
        $part
        ! replace(.,$xqc:token-re,"$1 $2 $3")
        ! replace(.,":([%\p{N}])"," : $1")
        ! replace(.,": =",":=")
        ! replace(.,"(group|instance|treat|cast|castable|order)\s+(by|of|as)","$1-$2")
        ! replace(.,concat("([",$xqc:block-chars,"])([^\s])"),"$1 $2")
        ! replace(.,concat("([",$xqc:block-chars,"])([^\s])"),"$1 $2")
        ! replace(.,concat("([^\s])([",$xqc:block-chars,"])"),"$1 $2")
        ! replace(.,concat("(\s\p{N}+)(\-)([^\s])|([",$xqc:block-chars,$xqc:stop-chars,"]+)(\-)([^\s])"),"$1 $2 $3")
        ! replace(.,"\(\s+:","(:")
        ! replace(.,":\s+\)",":)")
(:        ! concat(., " ;"):)
        ! tokenize(.,"\s+")
};

declare function xqc:wrap-depth($parts as map(*)*,$ret as array(*),$depth as xs:integer,$o as array(*),$i as map(*),$p as array(*),$params as map(*)){
    if(empty($parts)) then
        $ret
    else
        let $out :=
            if(exists($parts)) then
                head($parts)
            else
                ()
        let $tmp := fold-left($out, map {
            "r": $ret,
            "d": $depth,
            "o": $o,
            "i": $i,
            "p": $p
        }, function($pre,$cur){
            if(exists($cur)) then
                let $tmp := xqc:process($cur,$pre("r"),$pre("d"),$pre("o"),$pre("i"),$pre("p"))
(:                let $nu := console:log($tmp("r")):)
                return $tmp
            else
                $pre
        })
        return xqc:wrap-depth(tail($parts),$tmp("r"),$tmp("d"),$tmp("o"),$tmp("i"),$tmp("p"),$params)
};


declare function xqc:to-l3($pre,$entry,$at,$normalform,$size){
    let $t := $entry("t")
    let $v := $entry("v")
    let $s :=
        if($t = 1) then
            if($v eq "{") then
                15
            else if($v eq "(") then
                (: TODO check for last operator :)
                let $last := if($at gt 1) then $normalform($at - 1) else ()
                return if(exists($last) and $last("t") = (4,6,10)) then () else if(exists($last) and $last("t") eq 2) then () else (14,"")
            else
                ()
        else if($t eq 2) then
            let $next := if($at lt $size) then $normalform($at + 1) else ()
            return if(exists($next) and $next("t") eq 1) then 18 else 17
        else if($t eq 7) then
            (3,$v)
        else if($t eq 8) then
            (12,$v)
        else if($t eq 6) then
            let $next := if($at lt $size) then $normalform($at + 1) else ()
            return if(exists($next) and $next("t") eq 1) then (14,$v) else (3,$v)
        else if($t = (4,10)) then
            (14,$v)
        else if($t eq 5) then
            (3,$v)
        else if($t eq 11) then
            (8,$v)
        else
            ()
    return ($pre,$s)
};

declare function xqc:normalize-query-b($query as xs:string?,$params as map(*)) {
    (: TODO strip comments for now :)
    let $normalform := xqc:wrap-depth(xqc:analyze-chars(string-to-codepoints($query) ! codepoints-to-string(.)),[],1,[],map {},[],$params)
    let $output := $params("$transpile")
    return
        if($output eq "rdl") then
            a:fold-left($normalform,"",function($pre,$entry){
                let $t := $entry("t")
                let $v := $entry("v")
                return concat(
                    $pre,
                    if($t eq 7) then
                        concat("&quot;",$v,"&quot;")
                    else if($t eq 11) then
                        concat("(:",$v,":)")
                    else
                        $v
                )
                        
            })
        else if($output eq "l3") then
            a:fold-left-at($normalform,(),function($pre,$entry,$at){
                xqc:to-l3($pre,$entry,$at,$normalform,array:size($normalform))
            })
        else
            $normalform
};


(:
ws = 0
open paren = 1
close paren = 2
open curly = 3
close curly = 4
open square = 5
close square = 6
lt = 7
gt = 8
comma = 9
semicolon = 10
colon = 11
quot = 12
apos = 13
slash = 14
eq = 15

reserved = 4 (known operator)
var = 5 ($qname)
qname = 6
string = 7
number = 8
comment = 9
xml = 10
attrkey = 11
attrval = 12
enclosed expr = 13

string (type won't change):
    open=1 -> not(string, comment) and quot or apos
    clos=2 -> string and quot or apos
comment:
    open=3 -> not(string, xml) old = open paren and cur = colon
    clos=4 -> comment and old = colon and cur = close paren
opening-tag:
    open=5 -> cur=qname and old=lt
    clos=6 -> opening-tag and cur=gt
closing-tag:
    open=7 -> xml and old=lt and cur=slash
    clos=8 -> xml and cur=gt
xml:
    open -> opening-tag
    close -> closing-tag and count=0
attrkey:
    open=9 -> xml and cur=qname and old=ws
    clos=10 -> attrkey and eq
attrval:
enclosed expr (cancel on cur=old):
    open=11 -> xml and old=open-curly and cur!=open-curly
    clos=12 -> enc-exp and old=close-curly and cur!=close-curly
:)
declare function xqc:analyze-char($char) {
    switch($char)
        case "(" return 1
        case ")" return 2
        case "{" return 3
        case "}" return 4
        case "[" return 5
        case "]" return 6
        case "<" return 7
        case ">" return 8
        case "," return 9
        case ";" return 10
        case ":" return 11
        case "&quot;" return 12
        case "&apos;" return 13
        case "/" return 14
        case "=" return 15
        default return ()
};

declare function xqc:analyze-chars($chars) {
    xqc:analyze-chars((),tail($chars),head($chars),0,(),0,false(),false(),false(),false(),false(),false(),0)
};

declare function xqc:analyze-chars($ret,$chars,$char,$old-type,$buffer,$string,$comment,$opentag,$closetag,$attrkey,$attrval,$enc-expr,$opencount) {
    (: if the type changes, flush the buffer :)
    (: TODO:
        * WS for XML
        * type 10 instead of 0 for enclosed expression
    :)
    let $type := 
        if($string) then
            (: skip anything but closers :)
            if($char eq "&quot;") then
                12
            else if($char eq "&apos;") then
                13
            else
                $old-type
        else if(matches($char,"\s")) then
            0
        else
            xqc:analyze-char($char)
    let $zero := if(($comment,$opentag,$closetag) = true()) then false() else $string eq 0
    let $flag := 
        if($zero) then
            if($type = (12,13)) then
                1 (: open string :)
            else if($type eq 11 and $old-type eq 1) then
                3 (: open comment :)
            else if($old-type eq 7) then
                if(matches($char,"[\p{L}\p{N}\-_:]")) then
                    5 (: open opentag :)
                else if($type eq 14 and head($opencount) gt 0) then
                    7 (: open closetag :)
                else
                    ()
            else if($type eq 3 and head($opencount) gt 0) then
                11 (: open enc-expr :)
            else if($enc-expr and $type eq 4) then
                12 (: close enc-expr :)
            else
                ()
        else
            if($string and $type = (12,13)) then
                2 (: close string :)
            else if($comment and $type eq 2 and $old-type eq 11) then
                4 (: close comment :)
            else if($opentag and $type eq 8) then
                6 (: close opentag :)
            else if($closetag and $type eq 8) then
                8 (: close closetag :)
            else
                ()
    return if(empty($chars)) then
        let $emit-buffer := if($flag) then 
                if(exists($buffer)) then
                    string-join($buffer)
                else
                    ()
            else if(exists($buffer)) then
                string-join(($buffer,$char))
            else
                $char
        return
            ($ret,
                if($flag = (2,4,6,8) and $emit-buffer) then
                    map { "t":(if($flag eq 2) then
                            7
                        else if($flag eq 8) then
                            2
                        else
                            9 + $flag div 2
                        ),"v":$emit-buffer}
                else
                    tokenize($emit-buffer,";") ! xqc:prepare-tokens(.) ! xqc:inspect-buf(.)
            )
    else
        let $opencount :=
            if($flag eq 5) then
                (head($opencount) + 1,tail($opencount))
            else if($flag eq 7) then
                (head($opencount) - 1,tail($opencount))
            else
                $opencount
        let $nu := console:log(map {
            "type": $type,
            "char":$char,
            "flag":$flag,
            "buffer":$buffer,
            "comment":$comment,
            "opencount":$opencount,
            "zero": $zero,
            "enc-expr":$enc-expr,
            "ret":$ret
        })
        (: closers van string, comment, opentag, closetag moeten worden vervangen :)
        let $emit-buffer :=
            if($flag and exists($buffer)) then
                let $buffer := 
                    if($flag = (3,4,5,7)) then 
                        subsequence($buffer,1,count($buffer) - 1)
                    else
                        $buffer
(:                    let $buffer := $buffer[matches(.,"^\s*$") eq false()]:)
                return
                    if(exists(tail($buffer)) or matches($buffer,"^\s*$") eq false()) then
                        string-join($buffer)
                    else
                        ()
            else
                ()
        return xqc:analyze-chars(
            ($ret,
                if($flag = (2,4,6,8) and $emit-buffer) then
                    map {
                        "t": (if($flag eq 2) then
                            7
                        else if($flag eq 8) then
                            2
                        else
                            9 + $flag div 2
                        ),
                        "v":$emit-buffer
                    }
                else
                    tokenize($emit-buffer,";") ! xqc:prepare-tokens(.) ! xqc:inspect-buf(.)
            ),
            tail($chars),
            head($chars),
            if($type = (12,13)) then 0 else $type,
            if($flag) then
                if($flag eq 5 and $char) then $char else ()
            else
                ($buffer,$char),
            if($flag eq 1) then
                $type
            else if($flag eq 2) then
                0
            else
                $string,
            if($flag eq 3) then
                true()
            else if($flag eq 4) then
                false()
            else
                $comment,
            if($flag eq 5) then
                true()
            else if($flag eq 6) then
                false()
            else
                $opentag,
            if($flag eq 7) then
                true()
            else if($flag eq 8) then
                false()
            else
                $closetag,
            $attrkey,
            $attrval,
            if($flag eq 11) then
                true()
            else if($flag eq 12) then
                false()
            else
                $enc-expr,
            if($flag eq 11) then 
                (0,$opencount)
            else if($flag eq 12) then 
                tail($opencount)
            else
                $opencount
        )
};
