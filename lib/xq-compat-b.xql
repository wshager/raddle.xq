xquery version "3.1";

module namespace xqc="http://raddle.org/xquery-compat";

import module namespace console="http://exist-db.org/xquery/console";
import module namespace a="http://raddle.org/array-util" at "../lib/array-util.xql";
import module namespace dawg="http://lagua.nl/dawg" at "../lib/dawg.xql";


declare variable $xqc:ncform := "\p{L}\p{N}\-_";
declare variable $xqc:ncname := concat("^[",$xqc:ncform,"]");
declare variable $xqc:qform := concat("[",$xqc:ncform,"]*:?[",$xqc:ncform,"]+");
declare variable $xqc:qname := concat("^",$xqc:qform,"$");
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
	801: "+",
	802: "-",
	901: "*",
	902: "idiv",
	903: "div",
	904: "mod",
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
	801: "add",
	802: "subtract",
	901: "multiply",
	1002: "union",
	1701: "plus",
	1702: "minus",
	1800: "x-for-each",
	1901: "select",
(:	1902: "select-deep",:)
	2001: "x-filter",
	2003: "lookup",
	2004: "array",
	2005: "pair"
};

declare variable $xqc:operator-trie := json-doc("/db/apps/raddle.xq/operator-trie.json");

declare variable $xqc:fns := (
	"position","last","name","node-name","nilled","string","data","base-uri","document-uri","number","string-length","normalize-space"
);

declare variable $xqc:uri-chars := map {
    "%3E" : ">",
    "%3C" : "<",
    "%2C" : ",",
    "%3A" : ":"
};

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

declare function xqc:inspect-buf($s,$params){
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
                (: typically an unmatched : in maps :)
                (: TODO perform partial analysis, because it may contain a qname :)
                if(matches($s,":")) then
                    analyze-string($s,":")//text() ! xqc:inspect-buf(.,$params)
                else if(matches($s,"^\-")) then
                    analyze-string($s,"\-")//text() ! xqc:inspect-buf(.,$params)
                else
                    let $nu := console:log($s) return
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
    (: closing a constructor is always detected, because the opening backet is never added to openers for constructors :)
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
    let $pass := $is-let and ($has-then or $has-op eq false() or $ov eq 3106 or $has-ret or $has-tuple)
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
    let $nu := console:log(("v: ",$v,", unwrap: ",$d, ", ocur: ",$ocur, ", has-ass: ", $has-ass, ", is-body: ", $is-body, ", pass: ",$pass, ", is-x: ",$is-x, ", has-x: ",$has-x,", xfor:",$has-xfor, ", has-xass: ", $has-xass, ", has-xret: ",$has-xret))
    let $r := if($has-else) then array:append($r,xqc:tpl(2,$d,"}")) else $r
    let $d := if($has-else) then $d - 1 else $d
    return
        if($osize eq 0 or $pass or $has-ass or $is-body or $has-typesig or $has-params or $has-af or $matching or $close-then or $is-xret or $has-xret or $is-x or $has-x or $has-xfor) then
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
                if($has-params) then
                    (xqc:tpl(5,$d,"item"),xqc:tpl(1,$d,"("),xqc:tpl(2,$d,")"),$cur)
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
                                xqc:tpl(4,$d+1,concat("$",$i)),
                                xqc:tpl(2,$d,")"),
                                if($is-let) then () else xqc:tpl(3,$d,",")
                            })
                else if($has-xret) then
                    (xqc:tpl(1,$d,"}"),xqc:tpl(2,$d - 1,")"),xqc:tpl(2,$d - 2,")"))
                else if($is-x and $has-x) then
                    ($tpl,xqc:tpl(3,$d,","))
                else if($is-body) then
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
                else if($has-ass) then
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
                else if($has-params or ($has-ass and $r($size)("t") ne 3) or $is-body or $has-af or $matching or $close-then or $is-xret or $is-x) then
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
                        if($is-body or $has-xret) then
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
            let $nu := console:log("auto")
            return
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
        let $r := if(exists($tpl)) then fold-left($tpl,$r,array:append#2) else $r
        return
            map {
                "d": $d,
                "o": if(exists($new-op)) then array:append($o, $new-op) else $o,
                "i": if(exists($tpl)) then map:put($i, $tpl[1]("d"), array:size($r) - count($tpl) + 1) else $i,
                "r": $r,
                "p": if($param) then array:append($p,$param) else $p
            }
    else
        let $r := if(exists($tpl)) then fold-left($tpl,$r,array:append#2) else $r
        return
            map {
                "d": $d,
                "o": if(exists($new-op)) then array:append($o, $new-op) else $o,
                "i": if(exists($tpl)) then map:put($i, $tpl[1]("d"), array:size($r) - count($tpl) + 1) else $i,
                "r": $r,
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
        let $has-pre-op := $has-op and $ocur("v") >= 300 and $ocur("v") < 1900
        return
            if($t eq 0) then
                xqc:unwrap($cur,$ret,$d,$o,$i,$p)
            else if($t eq 1) then
                if($v eq "[") then
                    let $cur := xqc:tpl($t,$d,$v)
                    (: TODO pull in right-side if filter, except when select :)
                    let $has-select := $has-op and $ocur("v") eq 1901
                    let $it := if($size eq 0 or $ret($size)("t") = (1,3)) then 2004 else 2001
                    let $cur := xqc:tpl(4,$d,xqc:op-name($it))
                    let $ret :=
                        if($it eq 2001 and $has-select eq false()) then
                            let $split := $i($d)
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
                    let $has-constr-type := $has-params eq false() and $has-op and $ocur("v") gt 2100 and $ocur("v") lt 2200
    (:                let $nu := console:log(($d,", has-params: ",$has-params,", has-rettype: ",$has-rettype)):)
                    let $cur := xqc:tpl($t,$d,$v)
                    let $tpl :=
                        if($has-params) then
                            let $tpl :=
                                if($has-rettype) then
                                    xqc:tpl(2,$d,")")
                                else
                                    (xqc:tpl(3,$d,","),xqc:tpl(5,$d,"item"),xqc:tpl(1,$d,"("),xqc:tpl(2,$d,")"),xqc:tpl(2,$d,")"))
                            return
                                a:fold-left-at($p,($tpl,xqc:tpl(3,$d - 1,","),$cur),function($pre,$cur,$i) {
                                    ($pre,xqc:tpl(10,$d,"$"),xqc:tpl(1,$d,"("),xqc:tpl(4,$d+1,$cur),xqc:tpl(3,$d+1,","),xqc:tpl(4,$d+1,concat("$",$i)),xqc:tpl(2,$d,")"),xqc:tpl(3,$d,","))
                                })
                        else if($has-op) then
                            xqc:tpl($t,$d,"(")
                        else
                            xqc:tpl($t,$d,$v)
                    let $o :=
                        if($has-constr-type) then
                            array:append(a:pop($o),xqc:tpl($ocur("t"),$ocur("d"),$ocur("v") + 900))
                        else
                            $o
                    return
                        (: remove constr type if not constr :)
                        xqc:rtp($ret,if($has-params) then $d else $d + 1,$o,$i,if($has-params) then [] else $p,$tpl,(),if($has-params) then () else $cur)
                else
                    (: detect first opening bracket after function declaration :)
                    (: detect parameters, we need to change 2106 to something else at opening bracket here :)
                    let $has-func := $has-op and $ocur("v") eq 2106
                    let $has-constr-type := $has-func eq false() and $has-op and $ocur("v") gt 2100 and $ocur("v") lt 2200
                    let $cur := xqc:tpl($t,$d,$v)
                    let $tpl :=
                        if($has-func) then
                            (xqc:tpl(3,$d,","),xqc:tpl(4,$d,"function"),$cur,xqc:tpl($t,$d + 1,$v))
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
                if($has-op and $ocur("v") eq 210) then
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
                            (xqc:tpl(5,$d,"item"),xqc:tpl(1,$d,"("),xqc:tpl(2,$d,")"),$cur)
                        else
                            $cur
                    return xqc:rtp($ret,$d,$o,$i,$p,$tpl,$has-typesig)
            else if($t eq 4) then
                if($v eq 217) then
                    xqc:rtp($ret,$d,$o,$i,$p,(),(),xqc:tpl($t,$d,$v))
                else if($v eq 218) then
                    (: TODO check if o contains declare (would it not?) :)
                    xqc:rtp($ret,$d + 1, $o, $i,$p, (xqc:tpl(10,$d,"$"),xqc:tpl(1,$d,"(")),$has-op and $ocur("v") eq 217,xqc:tpl($t,$d,$v))
                else if($v eq 2106) then
                    (: TODO check if o contains declare (would it not?) :)
                    if($ocur("t") eq 4 and $ocur("v") eq 217) then
                        xqc:rtp($ret,$d + 1, $o, $i,$p, (xqc:tpl(10,$d,"$"),xqc:tpl(1,$d,"(")),$has-op and $ocur("v") eq 217,xqc:tpl($t,$d,$v))
                    else
                        xqc:rtp($ret,$d + 1, $o, $i,$p, xqc:tpl($t,$d,xqc:op-name($v)))
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
                    return xqc:rtp($tmp("r"),$d + 1, $tmp("o"), $tmp("i"),$tmp("p"), if($has-x) then () else (xqc:tpl(10,$d,"$"),xqc:tpl(1,$d,"(")),(),xqc:tpl($t,$d,$v))
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
                else if($v >= 300 and $v < 2100) then
                    if($size eq 0) then
                        (: nothing before, so op must be unary :)
(:                        let $nu := console:log(("un-op: ",$v)):)
                        (: unary-op: insert op + parens :)
                        let $v := $v + 900
                        return xqc:rtp($ret,$d + 1, $o, $i,$p, (xqc:tpl($t,$d,xqc:op-name($v)),xqc:tpl(1,$d,"(")),(),xqc:tpl($t,$d,$v))
                    else
                        let $prev := $ret($size)
                        return
                            if(($v eq 901 and $ocur("t") eq 1) or ($v = (801,901) and $has-op and $ocur("v") eq 2400)) then
                                (: these operators are occurrence indicators when the previous is an open paren or qname :)
                                (: when the previous is a closed paren, it depends what the next will be :)
                                xqc:rtp($ret,$d,$o,$i,$p,xqc:tpl($t,$d,$xqc:operators($v)))
                            else if($v = (801,802) and $prev("t") = (1,3,4)) then
                                let $v := $v + 900
                                return xqc:rtp($ret,$d + 1, $o, $i,$p, (xqc:tpl($t,$d,xqc:op-name($v)),xqc:tpl(1,$d,"(")), (), xqc:tpl($t,$d,$v))
                            else
                                (: bin-op: pull in left side, add parens :)
                                let $preceding-op := if($has-pre-op) then $ocur("v") gt $v else false()
                                let $nu := console:log(("bin-op: ",$v,", prec: ",$preceding-op))
                                (: if preceding, lower depth, as to takes the previous index :)
                                (: furthermore, close directly and remove the operator :)
                                let $d :=
                                    if($preceding-op) then
                                        $d - 1
                                    else
                                        $d
                                let $split := $i($d)
                                let $nu := console:log($ret($split))
(:                                let $split := if($ret($split)("t") eq 1) then $split - 1 else $split:)
                                let $left :=
(:                                    if($v eq 1901 and $has-op and $ocur("v") eq 1901) then:)
(:                                        []:)
(:                                    else :)
                                    if($preceding-op) then
                                        array:append(xqc:incr(array:subarray($ret,$split)),xqc:tpl(2,$d + 1,")"))
                                    else
                                        xqc:incr(array:subarray($ret,$split))
                                let $nu := console:log($left)
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
        ! concat(., " ;")
        ! tokenize(.,"\s+")
};

declare function xqc:wrap-depth($parts as xs:string*,$ret as array(*),$depth as xs:integer,$o as array(*),$i as map(*),$p as array(*),$params as map(*)){
    if(empty($parts)) then
        $ret
    else
        let $out :=
            if(exists($parts)) then
                xqc:inspect-buf(head($parts),$params)
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
                let $nu := console:log($tmp("r"))
                return $tmp
            else
                $pre
        })
        return xqc:wrap-depth(tail($parts),$tmp("r"),$tmp("d"),$tmp("o"),$tmp("i"),$tmp("p"),$params)
};

declare function xqc:normalize-query-b($query as xs:string?,$params as map(*)) {
    for-each(for-each(tokenize($query,";"),function($part) {
        xqc:wrap-depth(xqc:prepare-tokens($part),[],1,[],map {},[],$params)
    }), function($a){
        a:fold-left($a,"",function($pre,$entry){
            concat($pre,$entry("v"))
        })
    })
};
