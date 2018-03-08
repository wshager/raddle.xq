xquery version "3.1";

module namespace xqc="http://raddle.org/xquery-compat";

import module namespace console="http://exist-db.org/xquery/console";
import module namespace a="http://raddle.org/array-util" at "../lib/array-util.xql";
import module namespace dawg="http://lagua.nl/dawg" at "../lib/dawg.xql";

(:
semicolon = 0
open = 1
close = 2
comma = 3
reserved = 4 (known operator)
var = 5 ($qname)
qname = 6
string = 7
number = 8
comment = 9
$ = 10
xml = 11
attrkey = 12
unknown = 13
 :)

declare variable $xqc:ncform := "\p{L}\p{N}\-_";
declare variable $xqc:ncname := concat("^[",$xqc:ncform,"]");
declare variable $xqc:qform := concat("[",$xqc:ncform,":]+");
declare variable $xqc:qname := concat("^",$xqc:qform,"(#\p{N}+)?$");
declare variable $xqc:var-qname := concat("^\$",$xqc:qform,"$");
declare variable $xqc:operator-regexp := "=#\p{N}+=";

declare variable $xqc:operators as map(xs:integer, xs:string) := map {
    1:"(",
    2:")",
    3:"{",
    4:"}",
    5:";",
    6:"&quot;",
    7:"&apos;",
    8:".",
    9:"$",
    100:",",
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
	(: eq, ne, lt, le, gt, ge, =, !=, <, <=, >, >=, is, <<, >> :)
	501: ">>",
	502: "<<",
	503: "is",
	504: ">=",
	505: ">",
	506: "<=",
	507: "<",
	508: "!=",
	509: "=",
	510: "ge",
	511: "gt",
	512: "le",
	513: "lt",
	514: "ne",
	515: "eq",
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
	1902: "//",
	2001: "[",
	2002: "]",
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
	2600: ":"
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
	501: "precedes",
	502: "follows",
	503: "is",
	504: "gge",
	505: "ggt",
	506: "gle",
	507: "glt",
	508: "gne",
	509: "geq",
	510: "ge",
	511: "gt",
	512: "le",
	513: "lt",
	514: "ne",
	515: "eq",
	600: "concat",
	801: "subtract",
	802: "add",
	904: "multiply",
	1002: "union",
	1701: "plus",
	1702: "minus",
	1800: "x-for-each",
	1901: "select",
	1902: "select-deep",
	2001: "x-filter",
	2003: "lookup",
	2004: "array",
	2600: "pair",
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

declare function xqc:is-qname($b) {
    every $s in $b satisfies matches($s,$xqc:qform)
};

declare function xqc:is-number($b) {
    every $s in $b satisfies matches($s,"[\p{N}.]+")
};

declare function xqc:inspect-buf($s){
    if(empty($s)) then
        ()
    else
        let $ret := dawg:traverse($xqc:operator-trie,$s)
        return if(empty($ret) or $ret instance of array(*)) then
            if(xqc:is-qname($s)) then
                map { "t" : 6, "v" : string-join($s)}
            else if($s[1] eq "$") then
                map { "t" : 5, "v" : string-join($s)}
            else if($s[1] eq "&quot;") then
                map { "t" : 7, "v" : string-join($s)}
            else
                map { "t" : 13, "v" : $s}
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

declare function xqc:last($r,$size) {
    let $last := $r($size)
    return
        if(empty($last)) then
            map {}
        else if($last("t") eq 9 and $size gt 0) then
            xqc:last($r,$size - 1)
        else
            $last
};

declare function xqc:unwrap($cur,$r,$d,$o,$i,$p){
    (: TODO cleanup (e.g. separate is-close and is-op), apply for all cases :)
    let $osize := array:size($o)
    let $ocur := if($osize gt 0) then $o($osize) else map {}
    let $has-typesig := $ocur("t") eq 4 and $ocur("v") eq 2400
    let $o := if($has-typesig) then a:pop($o) else $o
    let $osize := if($has-typesig) then array:size($o) else $osize
    let $ocur := if($osize gt 0) then $o($osize) else map {}
    let $size := array:size($r)
    let $ot := $ocur("t")
    let $ov := $ocur("v")
    let $has-op := $ot eq 4
    let $t := $cur("t")
    let $v := $cur("v")
    let $type :=
        if($t eq 1) then
            if($v eq 1) then
                1
            else if($v eq 3) then
                3
            else if($v eq 2001) then
                2001
            else
                ()
        else if($t eq 2) then
            if($v eq 2) then
                2
            else if($v eq 4) then
                4
            else if($v eq 2002) then
                2002
            else
                ()
        else if($t eq 4) then
            $v
        else ()
    let $is-close := $t eq 2
    let $is-let := $type eq 209
    let $is-x := $type = (222,223,224,225)
    let $is-body := $type eq 4 and $has-op and $ov eq 3106
    let $has :=
        if($ot eq 1) then
            if($ov eq 1) then
                1
            else if($ov eq 3) then
                3
            else if($ov eq 2001) then
                2001
            else if($ov eq 2004) then
                2004
            else
                ()
        else if($ot eq 11) then
            $ot (: direct-elem-constr :)
        else if($has-op) then
            if($ov eq 210) then
               if($type = (209,211)) then $ov else ()
            else if(($ov gt 2100 and $ov lt 2200)) then
                2100
            else if($type eq 4 and ($ov gt 3000 and $ov lt 3100)) then
                2200 (: some constructor :)
            else if(($type eq 2 or $t eq 3) and $ov eq 3006) then
                3006 (: params :)
            else if($type eq 6 and $ov = (2001,2004)) then
                4000 (: array / filter :)
            else if($ov eq 211) then
                if($type eq 209) then 211 else 231 (: flwor return :)
            else if($ov = (207,208,221,222,223,224,225,1200,2600,2400)) then
                (:
                    * 207 = then
                    * 208 = else
                    * 221 = xfor
                    * 2600 = tuple
                    * 2400 = typesig
                :)
                $ov
            else
                ()
        else
            ()
    (: TODO only is let if at same depth! :)
    let $close-params := $type eq 2 and $has eq 3006
    let $has-ass := $has eq 210
    let $has-xfor := $has eq 221
    let $has-x := $has = (222,223,224,225)
    let $is-xlet := $is-let and $has-x
    (: closing a constructor is always detected, because the opening bracket is never added to openers for constructors :)
    let $has-constr := $has eq 2200
    let $has-constr-type := $has eq 2100
    (: has-params means there's no type-sig to close :)
    let $has-param := $has-typesig eq false() and $has eq 3006
    let $has-xret := $has eq 231
    let $pass := $type eq 209 and ($has eq 207 or $has-op eq false() or $ov eq 3106 or $has eq 211)
    let $pass := $pass or ($t eq 3 and $has eq 1) or $has eq 1200 or $osize eq 0
    let $has-af := $has eq 4000
    let $has-xass := $has-op and $ov eq 210 and ($is-x or ($has-ass and $osize gt 1 and $o($osize - 1)("t") eq 4 and $o($osize - 1)("v") = (222,223,224,225)))
    let $is-xret := $type eq 211 and ($has-x or $has-xass)
    let $matching := (
        ($type eq 4 and $has eq 3) or
        ($type eq 2 and $has eq 1) or
        ($type eq 2002 and $has = (2001,2004)))
    let $close-then := $type eq 208 and $has eq 207
(:    let $nu := if($close-then) then console:log(("has-params: ",$has-param,", is-type: ",$has-typesig," has-else: ",$has eq 208)) else ():)
    (: else adds a closing bracket :)
    let $nu := console:log($o)
    let $nu := console:log(map {
        "t":$t,
        "v":$v,
        "d":$d,
        "has":$has,
        "matching":$matching,
        "ocur":$ocur,
        "has-typesig":$has-typesig,
        "has-param":$has-param,
        "has-ass":$has-ass,
        "is-body":$is-body, 
        "pass":$pass,
        "ret":$r
    })
    let $is-let-in-else := $has eq 208 and $is-let eq true() and xqc:last($r,$size)("t") eq 1
    let $r := if($has eq 208 and $is-let-in-else eq false()) then array:append($r,xqc:tpl(2,$d,4)) else $r
    let $d := if($has eq 208 and $is-let-in-else) then $d - 1 else $d
    return
        if($osize eq 0 or $pass or $has-ass or $is-body or $is-let-in-else or $has-typesig or $has-param or $has-af or $matching or $close-then or $is-xret or $has-xret or $is-x or $has-x or $has-xfor or $has-constr or $has eq 2600 or $has eq 11) then
(:            let $nu := console:log("stop"):)
            let $tpl :=
                if($has-x or $has-xass) then
                    (xqc:tpl(1,$d,4),xqc:tpl(2,$d - 1,2),xqc:tpl(3,$d - 2,","))
                else
                    ()
            let $d := 
                if($has-x or $has-xass) then
                    $d - 2
                else
                    $d
            let $tpl :=
                if($has eq 2600) then
                    xqc:tpl(2,$d,2)
                else if($has-param) then
                    (xqc:tpl(4,$d,"item"),xqc:tpl(1,$d,1),xqc:tpl(2,$d,2),$cur)
                else if($is-xret or $is-x or $is-xlet) then
                    let $tpl := ($tpl,xqc:tpl(4,$d,$xqc:operators($v)),xqc:tpl(1,$d,1),xqc:tpl(1,$d+1,3))
                    let $d := $d + 2
                    return 
                        if($v eq 222) then
                            $tpl
                        else
                            a:fold-left-at($p,$tpl,function($pre,$cur,$i) {
                                $pre,
                                xqc:tpl(10,$d,"$"),
                                xqc:tpl(1,$d,1),
                                xqc:tpl(4,$d+1,$cur),
                                xqc:tpl(3,$d+1,","),
                                xqc:tpl(4,$d+1,"$"),
                                xqc:tpl(1,$d+1,1),
                                xqc:tpl(8,$d+2,$i),
                                xqc:tpl(2,$d+1,2),
                                xqc:tpl(2,$d,2),
                                if($is-let or $type eq 225) then () else xqc:tpl(3,$d,",")
                            })
                else if($has-xret) then
                    (xqc:tpl(2,$d,4),xqc:tpl(2,$d - 1,2),xqc:tpl(2,$d - 2,2))
                else if($is-x and $has-x) then
                    ($tpl,xqc:tpl(3,$d,","))
                else if($is-body or $has-constr) then
                    (xqc:tpl($t,$d,$v),xqc:tpl($t,$d - 1,2))
                else if($has-af or $is-close) then
                    let $close-curly :=
                        if($has eq 3) then
                            if($osize gt 1) then
                                $o($osize - 1)("t") ne 4
                            else
                                true()
                        else
                            false()
                    return xqc:tpl($t,$d,if($close-curly) then $v else 2)
                else if($pass or $close-then or $has-xfor) then
                    ()
                else if($has-ass) then
                    if($is-let and xqc:last($r,$size)("t") eq 3) then
                        ()
                    else
                        (xqc:tpl(2,$d,2),xqc:tpl(3,$d - 1,","))
                else if($is-let) then
                    ()
                else
                    xqc:tpl($t,$d,$v)
(:            let $nu := if($is-let) then console:log($tpl) else ():)
            let $o :=
                if($has-param or $has-constr or ($has-ass and xqc:last($r,$size)("t") ne 3) or $is-body or $has-af or $matching or $close-then or $is-xret or $is-x or $has eq 2600) then
                    a:pop($o)
                else
                    $o
            let $o :=
                if($close-params) then
                    array:append($o,xqc:tpl(4,$d,3106))
                else 
                    if($is-xret or $is-x) then
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
                        else if($has-ass or $has-param or $has-af or $matching) then
                            $d - 1
                        else $d,
                    "o": $o,
                    "i": if($pass) then $i else map:put($i, $d, array:size($r)),
                    "p": if($has-xret) then [] else $p
                }
        else
            let $nu := console:log("auto")
            let $r := if($has-op and ($ov gt 3000 or $has-constr-type)) then $r else array:append($r,xqc:tpl(2,$d,2))
            let $r := if($t eq 0) then array:append($r,xqc:tpl(0,$d,";")) else $r
            return
                xqc:unwrap($cur, $r, $d - 1, a:pop($o), map:put($i, $d, array:size($r)),$p)
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
                    xqc:rtp($ret,$d,$o,$i,$p,xqc:tpl(2,$d,2),true())
                else
                    let $tpl := xqc:last($ret,$size)
                    return xqc:rtp(a:put($ret,$size,xqc:tpl(7,$tpl("d"),concat($tpl("v")," ",$v))),$d,$o,$i,$p)
            else if($t eq 0) then
                xqc:unwrap($cur,$ret,$d,$o,$i,$p)
            else if($t eq 1) then
                if($v eq 2001) then
                    let $cur := xqc:tpl($t,$d,$v)
                    (: TODO pull in right-side if filter, except when select :)
                    let $has-select := $has-op and $ocur("v") eq 1901
                    let $it := if($size eq 0 or (xqc:last($ret,$size)("t") = (1,3,6) and $has-select eq false())) then 2004 else 2001
                    let $cur := xqc:tpl(4,$d,xqc:op-name($it))
                    let $ret :=
                        if($it eq 2001 and $has-select eq false()) then
                            let $split := $i($d)
(:                            let $split := if($ret($split)("t") eq 1) then $split - 1 else $split:)
                            let $left := xqc:incr(array:subarray($ret,$split))
                            let $ret := array:subarray($ret,1,$split - 1)
                            return array:join(($ret,[$cur,xqc:tpl(1,$d,1)],$left))
                        else
                            $ret
                    let $tpl :=
                        if($it eq 2001) then
                            if($has-select) then
                                (xqc:tpl(3,$d,","),$cur,xqc:tpl(1,$d,1))
                            else
                                xqc:tpl(3,$d,",")
                        else
                            ($cur,xqc:tpl(1,$d,1))
                    return xqc:rtp($ret,$d + 1,$o,$i,$p,$tpl,false(),xqc:tpl(1,$d,$it))
                else if($v eq 3) then
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
                                    xqc:tpl(2,$d,2)
                                else
                                    (xqc:tpl(3,$d,","),xqc:tpl(4,$d,"item"),xqc:tpl(1,$d,1),xqc:tpl(2,$d,2),xqc:tpl(2,$d,2))
                            return
                                a:fold-left-at($p,($tpl,xqc:tpl(3,$d - 1,","),$cur),function($pre,$cur,$i) {
                                    ($pre,xqc:tpl(10,$d,"$"),xqc:tpl(1,$d,1),xqc:tpl(5,$d+1,$cur),xqc:tpl(3,$d+1,","),xqc:tpl(10,$d+1,"$"),xqc:tpl(1,$d,1),xqc:tpl(8,$d,string($i)),xqc:tpl(2,$d,2),xqc:tpl(2,$d,2),xqc:tpl(3,$d,","))
                                })
                        else if($has-constr-type) then
                            $cur
                        else if($has-op) then
                            xqc:tpl($t,$d,1)
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
                    let $last := if($size) then xqc:last($ret,$size) else map {}
                    let $has-lambda := $has-func and $last("t") eq 4
(:                    let $nu := console:log(map {:)
(:                        "has-func":$has-func,:)
(:                        "has-lambda":$has-lambda,:)
(:                        "last":$last:)
(:                    }):)
                    
                    let $ret :=
                        if($has-lambda) then
                            a:pop($ret)
                        else
                            $ret
                    let $tpl :=
                        if($has-func) then
                            let $tpl := (xqc:tpl(4,$d,"function"),$cur,xqc:tpl(4,$d+1,""))
                            return
                                if($has-lambda) then
                                    (xqc:tpl(4,$d,"quote-typed"),$cur,$tpl)
                                else
                                    (xqc:tpl(3,$d,","),$tpl)
                        else if($size eq 0 or xqc:last($ret,$size)("t") = (1,3)) then
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
                if(($has-op and $ocur("v") eq 3006) or ($ocur("t") eq 1 and $ocur("v") eq 2004)) then
                    let $cur := xqc:tpl($t,$d,$v)
                    let $tpl := 
                        if($ocur("v") eq 3006) then
                            (xqc:tpl(4,$d,"item"),xqc:tpl(1,$d,1),xqc:tpl(2,$d,2),$cur)
                        else
                            $cur
                    return xqc:rtp($ret, $d, $o, $i, $p, $tpl)
                else
                    let $cur := xqc:tpl($t,$d,$v)
                    let $has-ass := $ocur("v") eq 210
                    let $tmp := xqc:unwrap(if($has-ass) then xqc:tpl(4,$d,209) else $cur, $ret, $d, $o, $i,  $p)
                    let $d := $tmp("d")
                    let $has-typesig := $has-op and $ocur("v") eq 2400
                    let $tpl :=
                        if($has-ass) then
                            (xqc:tpl(10,$d,"$"),xqc:tpl(1,$d,1))
                        else if($has-typesig or ($has-op and $ocur("v") = (210,700))) then
                            ()
                        else
                            $cur
                    return xqc:rtp($tmp("r"), $d + 1, $tmp("o"), $tmp("i"),$tmp("p"), $tpl, (), if($has-ass) then xqc:tpl(4,$d,209) else ())
            else if($t eq 4) then
                if($v eq 217) then
                    xqc:rtp($ret,$d,$o,$i,$p,(),(),xqc:tpl($t,$d,$v))
                else if($v eq 218) then
                    (: TODO check if o contains declare (would it not?) :)
                    xqc:rtp($ret,$d + 1, $o, $i,$p, (xqc:tpl(10,$d,"$>"),xqc:tpl(1,$d,1)),$has-op and $ocur("v") eq 217,xqc:tpl($t,$d,$v))
                else if($v eq 216) then
                    if($has-op and $ocur("v") eq 219) then
                        xqc:rtp(a:pop($ret),$d + 1,$o,$i,$p,(xqc:tpl($t,$d,"$<"),xqc:tpl(1,$d,1)),true(),xqc:tpl($t,$d,$v))
                    else
                        xqc:rtp($ret,$d + 1,$o,$i,$p,(xqc:tpl($t,$d,"$*"),xqc:tpl(1,$d,1)),$has-pre-op)
                else if($v eq 215) then
                    xqc:rtp($ret,$d + 1,$o,$i,$p,(xqc:tpl(4,$d,"xq-version"),xqc:tpl(1,$d,1)),$has-op,xqc:tpl($t,$d,$v))
                else if($v = (214,2108)) then
                    xqc:rtp($ret,$d,$o,$i,$p,(),$has-op,xqc:tpl($t,$d,$v))
                else if($v eq 219) then
                    xqc:rtp($ret,$d,$o,$i,$p,xqc:tpl($t,$d,xqc:op-name($v)),$has-pre-op,xqc:tpl($t,$d,$v))
                else if($v eq 2106) then
                    (: check if o contains declare, otherwise it's anonymous :)
                    let $has-decl := $has-op and $ocur("v") eq 217
                    let $tpl :=
                        if($has-decl) then
                            (xqc:tpl(10,$d,"$>"),xqc:tpl(1,$d,1))
                        else
                            xqc:tpl($t,$d,$v)
                    return xqc:rtp($ret,$d + 1, $o, $i,$p, $tpl,$has-decl,xqc:tpl($t,$d,$v))
                else if($v eq 2400) then
                    let $has-params := $has-op and $ocur("v") eq 3006
                    return xqc:rtp($ret,$d, $o, $i,$p, if($has-params) then () else xqc:tpl(3,$d,","), (), xqc:tpl($t,$d,$v))
                else if($v eq 207) then
                    xqc:rtp(a:pop($ret),$d + 2,$o,$i,$p,(xqc:tpl(3,$d + 1,","),xqc:tpl(1,$d + 1,3)),false(),xqc:tpl($t,$d,$v))
                else if($v eq 208) then
                    let $tmp := xqc:unwrap(xqc:tpl($t,$d,$v), $ret, $d, $o, $i, $p)
                    let $d := $tmp("d")
                    return xqc:rtp($tmp("r"),$d,$tmp("o"),$tmp("i"),$tmp("p"),(xqc:tpl(2,$d,4),xqc:tpl(3,$d - 1,","),xqc:tpl(1,$d - 1,3)),false(),xqc:tpl($t,$d,$v))
                else if($v eq 209) then
                    (: TODO check if o contains something that prevents creating a new let-ret-seq :)
                    (: remove entry :)
                    let $has-x := $has-op and $ocur("v") = (222,223,224,225)
                    let $tmp := xqc:unwrap(xqc:tpl($t,$d,$v), $ret, $d, $o, $i, $p)
                    let $d := $tmp("d")
                    let $o := $tmp("o")
                    (: wrap inner let :)
                    let $open := if(empty($ocur("t")) ) then xqc:tpl(1,$d,1) else ()
                    let $o := if(exists($open)) then array:append($o,xqc:tpl(1,$d,1)) else $o
                    return xqc:rtp($tmp("r"),$d + 2, $o, $tmp("i"),$tmp("p"), if($has-x) then () else ($open,xqc:tpl(10,$d + 1,"$"),xqc:tpl(1,$d + 1,1)),(),xqc:tpl($t,$d,$v))
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
                        xqc:rtp($ret,$d,$o,$i,$p,(xqc:tpl(1,$d,4),xqc:tpl(2,$d,2),xqc:tpl(3,$d,",")),(),xqc:tpl($t,$d,$v))
                    else
                        xqc:rtp($ret,$d + 1,$o,$i,$p,(xqc:tpl(4,$d,"for"),xqc:tpl(1,$d,1)),(),xqc:tpl($t,$d,$v))
                else if($v = (222,223,224,225)) then
                    (: x-in/x-where/x-orderby/x-groupby, remove x-... from o :)
                    xqc:unwrap(xqc:tpl($t,$d,$v),$ret,$d,$o,$i,$p)
                else if($v eq 509 and $has-op and $ocur("v") eq 2108) then
(:                    let $nu := console:log($ocur) return:)
                    xqc:rtp($ret,$d,$o,$i,$p,xqc:tpl(3,$d,","),true(),xqc:tpl($t,$d,$v))
                else if(($v ge 300 and $v lt 2100) or $v eq 2600) then
                    if($size eq 0) then
                        (: nothing before, so op must be unary :)
(:                        let $nu := console:log(("una-op: ",$v)):)
                        (: unary-op: insert op + parens :)
                        let $v := $v + 900
                        return xqc:rtp($ret,$d + 1, $o, $i,$p, (xqc:tpl($t,$d,xqc:op-name($v)),xqc:tpl(1,$d,1)),(),xqc:tpl($t,$d,$v))
                    else
                        let $prev := xqc:last($ret,$size)
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
                        let $is-occ := 
                            if($v = (802,904,2003)) then
                                if($ocur("t") eq 1 and $ocur("v") eq 1 and $osize gt 1) then
                                    let $olast := $o($osize - 1)
                                    return $olast("t") eq 4 and $olast("v") = (1200,2400)
                                else
                                    $has-op and $ocur("v") eq 2400
                            else
                                false()
                        return
                            if($is-occ) then
                                (: these operators are occurrence indicators when the previous is an open paren or qname :)
                                (: when the previous is a closed paren, it depends what the next will be :)
(:                                if($has-op) then:)
                                    let $split := $i($d)
                                    let $left := array:subarray($ret,1,$split - 1)
                                    let $right := array:subarray($ret,$split)
                                    return xqc:rtp($left,$d,$o,$i,$p,(
                                        xqc:tpl($t,$d,"occurs"),
                                        xqc:tpl(1,$d,1),
                                        array:flatten(xqc:incr($right)),
                                        xqc:tpl(3,$d,","),
                                        xqc:tpl($t,$d + 1,$xqc:occurrence($v)),
                                        xqc:tpl(1,$d + 1,1),
                                        xqc:tpl(2,$d + 1,2),
                                        xqc:tpl(2,$d,2)
                                    ))
(:                                else:)
(:                                    xqc:rtp($ret,$d,$o,$i,$p,xqc:tpl(7,$d,$xqc:operators($v))):)
                            else if($v = (801,802) and $prev("t") = (1,3,4)) then
                                let $v := $v + 900
                                return xqc:rtp($ret,$d + 1, $o, $i,$p, (xqc:tpl($t,$d,xqc:op-name($v)),xqc:tpl(1,$d,1)), (), xqc:tpl($t,$d,$v))
                            else
                                (: bin-op: pull in left side, add parens :)
                                let $preceding-op := if($has-pre-op and $ocur("v")) then $ocur("v") ge $v else false()
                                let $nu := console:log(("bin-op: ",$v,", prec: ",$ocur," d: ",$d,", i: ", $i))
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
                                        array:append(xqc:incr(array:subarray($ret,$split)),xqc:tpl(2,$d + 1,2))
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
(:                                let $ret := array:join((array:append($ret,xqc:tpl(1,$d,1)),$left)):)
                                return xqc:rtp($ret,$d + 1, $o, $i,$p, (xqc:tpl(1,$d+1,1),array:flatten($left),xqc:tpl(3,$d + 1,",")), (), xqc:tpl($t,$d,$v))
                    else if($v gt 2100 and $v lt 2200) then
                        xqc:rtp($ret,$d,$o,$i,$p,xqc:tpl($t,$d,xqc:op-name($v)),$has-pre-op and $ocur("v") ne 1200,xqc:tpl($t,$d,$v))
                    else
                        xqc:rtp($ret,$d,$o,$i,$p,xqc:tpl($t,$d,xqc:op-name($v)),$has-pre-op)
            else if($t eq 5) then
                    let $is-param := $has-op and $ocur("v") eq 3006
                    let $has-x := $has-op and $ocur("v") = (221,225)
                    let $has-ass := $has-op and $ocur("v") = (218,209)
                    let $has-xass := $has-ass and $osize gt 1 and $o($osize - 1)("t") eq 4 and $o($osize - 1)("v") = (222,223,224,225)
                    let $v := replace($v,"^\$","")
                    let $tpl :=
                        if($is-param or $has-xass or $has-x) then
                            ()
                        else if($has-ass) then
                            xqc:tpl($t,$d,$v)
                        else if($v eq "") then
                            xqc:tpl(10,$d,"$")
                        else
                            (xqc:tpl(10,$d,"$"),xqc:tpl(1,$d,1),xqc:tpl($t,$d + 1,$v),xqc:tpl(2,$d,2))
                    return xqc:rtp($ret,$d,$o,$i,$p,$tpl,(),(),if($is-param or $has-xass or $has-x) then $v else ())
            else if($t eq 6) then
                if($has-op and $ocur("v") = (2102,2105)) then
(:                let $nu := console:log(map {"auto-constr":$ocur,"i":$i}) return:)
                    let $tmp := xqc:rtp(a:pop($ret),$d + 1,$o,$i,$p,(xqc:tpl(4,$ocur("d"),$xqc:constructors($ocur("v"))),xqc:tpl(1,$d,1),xqc:tpl(1,$d+1,3),xqc:tpl(7,$d + 2,$v),xqc:tpl(2,$d + 2,4),xqc:tpl(3,$d + 1,",")),true(),xqc:tpl(4,$ocur("d"),$ocur("v") + 900))
                    return map:put($tmp,"i",$i)
                else
                    let $tpl := 
                        if($has-op and $ocur("v") eq 2108) then
                            xqc:tpl(7,$d,$v)
                        else if($has-op and $ocur("v") eq 2400 and matches($v,"^xs:")) then
                            (xqc:tpl(4,$d,replace($v,"^xs:","")),xqc:tpl(1,$d,1),xqc:tpl(2,$d,2))
                        else
                            xqc:tpl($t,$d,$v)
                    return xqc:rtp($ret,$d,$o,$i,$p,$tpl)
            else if($t eq 11) then
                xqc:rtp($ret,$d + 1,$o,$i,$p,xqc:tpl(11,$d,$v),(),xqc:tpl($t,$d,$v))
            else if($t eq 10) then
                let $is-for := $has-op and $ocur("v") eq 221
                let $tpl :=
                    if($is-for) then
                        ()
                    else
                        xqc:tpl($t,$d,$v)
                return xqc:rtp($ret,$d,$o,$i,$p,$tpl)
            else
                xqc:rtp($ret,$d,$o,$i,$p,xqc:tpl($t,$d,$v))
};

declare function xqc:wrap-depth($parts as map(*)*,$ret as array(*),$depth as xs:integer,$o as array(*),$i as map(*),$p as array(*),$params as map(*)){
    if(empty($parts)) then
        if($ret(array:size($ret))("t") ne 0) then xqc:unwrap(map {"t":0},$ret,$depth,$o,$i,$p)("r") else $ret
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
    let $Nu := console:log($entry)
    let $t := $entry("t")
    let $v := $entry("v")
    let $s :=
        if($t = 1) then
            if($v eq 3) then
                15
            else if($v eq 1) then
                (: TODO check for last operator :)
                let $last := if($at gt 1) then $normalform($at - 1) else ()
                return if(exists($last) and $last("t") = (4,6,10)) then () else if(exists($last) and $last("t") eq 2) then () else (14,"")
            else
                ()
        else if($t eq 2) then
            let $next := if($at lt $size) then $normalform($at + 1) else ()
(:            let $nu := console:log($next):)
            return if(exists($next) and $next("t") eq 1) then 18 else 17
        else if($t eq 7) then
            (3,$v)
        else if($t eq 8) then
            (12,$v)
        else if($t eq 6) then
            if(matches($v,"#\p{N}$")) then
                (4,$v)
            else
                let $next := if($at lt $size) then $normalform($at + 1) else ()
                return if(exists($next) and $next("t") eq 1) then (14,$v) else (3,$v)
        else if($t = (4,10)) then
            (14,$v)
        else if($t eq 5) then
            (3,$v)
        else if($t eq 9) then
            (8,$v)
        else if($t eq 11) then
            (1,$v)
        else if($t eq 12) then
            (2,$v)
        else
            ()
    return ($pre,$s)
};

declare function xqc:to-buffer($query as xs:string) {
    string-to-codepoints($query) ! codepoints-to-string(.)
};

declare function xqc:normalize-query($query as xs:string, $params as map(*)) {
    (: FIXME properly handle cases in replace below :)
    let $query := replace($query,"function\(\*\)","function(()*,item()*)")
    let $query := replace($query,"map\(\*\)","map(xs:anyAtomicType,item()*)")
    let $query := replace($query,"array\(\*\)","array(item()*)")
    return xqc:normalize-query-b(xqc:to-buffer($query),$params)
};

declare function xqc:normalize-query-b($buffer as xs:string*,$params as map(*)) {
    (: TODO strip comments for now :)
    let $prepared-buffer := xqc:analyze-chars($buffer,$params("$compat") eq "xquery")
(:    let $nu := console:log($prepared-buffer):)
    let $normalform := xqc:wrap-depth($prepared-buffer,[],1,[],map {},[],$params)
    let $output := $params("$transpile")
    return
        if($output eq "rdl") then
            a:fold-left($normalform,"",function($pre,$entry){
                let $t := $entry("t")
                let $v := $entry("v")
                return concat(
                    $pre,
                    if($t = (1,2)) then
                        $xqc:operators($v)
                    else if($t eq 7) then
                        concat("&quot;",$v,"&quot;")
                    else if($t eq 9) then
                        concat("(:",$v,":)")
                    else if($t eq 11) then
                        concat("n:e(",$v,",")
                    else
                            if($v) then
                                $v
                            else
                                ""
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

(: blocking chars :)
declare function xqc:analyze-char($char) {
    if($char eq "(") then
        1
    else if($char eq ")") then
        2
    else if($char eq "{") then
        3
    else if($char eq "}") then
        4
    else if($char eq "[") then
        2001
    else if($char eq "]") then
        2002
    else if($char eq ",") then
        100
    else if($char eq ">") then
        505
    else if($char eq "<") then
        507
    else if($char eq "=") then
        509
    else if($char eq ";") then
        5
    else if($char eq ":") then
        2600
    else if($char eq "+") then
        802
    else if($char eq "/") then
        1901
    else if($char eq "!") then
        1800
    else if($char eq "?") then
        2003
    else if($char eq "*") then
        904
    else if($char eq ".") then
        8
    else if($char eq "$") then
        9
    else if($char eq "&quot;") then
        6
    else if($char eq "&apos;") then
        7
    else if(matches($char,"\s")) then
        10
    else if(matches($char,"\p{N}")) then
        11
    else if(matches($char,"\p{L}")) then
        12
    else
        0
};

declare function xqc:flag-to-expr($flag) {
    if($flag eq 2) then
        7
    else if($flag eq 4) then
        9
    else if($flag = (6,9)) then
        11
    else if($flag eq 10) then
        12
    else if($flag eq 8) then
        2
    else
        13
};

declare function xqc:inspect-tokens($char,$type) {
    if($type = (1,3,2001)) then
        map {"t": 1, "v": $type}
    else if($type = (2,4,2002)) then
        map {"t": 2, "v": $type}
    else if($type eq 100) then
        map {"t": 3, "v": $char}
    else if($type eq 5) then
        map {"t": 0, "v": $char}
    else if($type eq 9) then
        map {"t": 10, "v": $char}
    else if($type eq 8) then
        map {"t": 7, "v": $char}
    else if($type = (505,507,509,802,904,1800,1901,2003,2600)) then
        map {"t": 4, "v": $type}
    else
        ()
};


declare function xqc:analyze-chars($chars,$xq-compat) {
    xqc:analyze-chars((),tail($chars),$xq-compat,head($chars),0,(),0,(),false(),false(),false(),false(),false(),false(),false(),false(),0,0)
};

declare function xqc:analyze-chars($ret,$chars,$xq-compat,$char,$old-type,$buffer,$string,$was-var,$was-qname,$was-number,$comment,$opentag,$closetag,$attrkey,$attrval,$enc-expr,$has-quot,$opencount) {
    (: if the type changes, flush the buffer :)
    (: TODO:
        * WS for XML
        * type 10 instead of 0 for enclosed expression
        * revert to pair checking, tokenize all chars here
    :)
    let $next := head($chars)
    let $type := 
        if($string ne 0) then
            (: skip anything but closers :)
            if($string eq 6 and $char eq "&quot;") then
                6
            else if($string eq 7 and $char eq "&apos;") then
                7
            else
                0
        else if($comment) then
            if($char eq ":") then
                if($next eq ")") then 2502 else 2600
            else
                0
        else if($opentag) then
            if($char eq ">") then
                505
            else if($char eq "/") then
                1901 (: TODO direct close :)
            else if(matches($char,"[\p{L}\p{N}\-_:]")) then
                0
            else if($char = ("=","&quot;")) then
                xqc:analyze-char($char)
            else
                (: TODO stop opentag, analyze the char :)
                ()
        else
            xqc:analyze-char($char)
    let $zero := if(($comment,$opentag,$closetag,$attrkey) = true()) then false() else $string eq 0
    let $var := $zero and (($was-var eq false() and $char eq "$") or ($was-var and matches($char,"[\p{L}\p{N}\-_:]")))
    let $number := $var eq false () and $zero and $type eq 11 and $old-type ne 12
    let $stop := empty($chars)
    let $flag :=
        if($number) then
            ()
        else if($zero) then
            if($type = (6,7)) then
                1 (: open string :)
            else if($type eq 1 and $next eq ":") then
                3 (: open comment :)
            else if($type eq 507) then
                if(matches($next,"\p{L}")) then
                    5 (: open opentag :)
                else if($next eq "/" and head($opencount) gt 0) then
                    7 (: open closetag :)
                else
                    ()
            else if($type eq 3 and $old-type ne 3 and $next ne "{" and head($opencount) gt 0) then
                11 (: open enc-expr :)
            else if($enc-expr and $type eq 4 and $has-quot eq 0 and $next ne "}") then
                12 (: close enc-expr :)
            else
                ()
        else
            if($string and $type = (6,7)) then
                2 (: close string :)
            else if($comment and $type eq 2502) then
                4 (: close comment :)
            else if($opentag and $type eq 505) then
                6 (: close opentag :)
            else if($closetag and $type eq 505) then
                8 (: close closetag :)
            else if($attrkey eq false() and empty($type) and head($opencount) gt 0) then
                9
            else if($attrkey and $type eq 509 and head($opencount) gt 0) then
                10
            else
                ()
    let $has-quot := 
        if(empty($flag)) then 
            if($type eq 3) then
                $has-quot + 1
            else if($type eq 4) then
                $has-quot - 1
            else $has-quot
        else $has-quot
    let $opencount :=
        if($flag eq 5) then
            (head($opencount) + 1,tail($opencount))
        else if($flag eq 7) then
            (head($opencount) - 1,tail($opencount))
        else
            $opencount
    (: closers van string, comment, opentag, closetag moeten worden vervangen :)
    let $emit-buffer :=
        if($flag) then
            if(exists($buffer)) then
                if($stop or exists(tail($buffer)) or $flag eq 2 or matches($buffer,"^\s*$") eq false()) then
                    string-join($buffer)
                else
                    ()
            else
                ()
        else if($zero) then
            if($was-var) then
                if($var) then
                    if($stop) then
                        string-join(($buffer,$char))
                    else 
                        ()
                else
                    string-join($buffer)
            else if($was-number) then
                if($type eq 2600) then
                    $char
                else if($number) then
                    if($stop) then
                        string-join(($buffer,$char))
                    else 
                        ()
                else
                    string-join($buffer)
            else if($type eq 10) then
                if(exists($chars) and exists($buffer) and matches(string-join($buffer),"^(group|instance|treat|cast|castable|order)$")) then
                    ()
                else
                    $char
            else if($type eq 2600 and $next eq "$") then
                $char
            else if($type ne 505 and $type ne 2600 and $type ne 509 and $type ne 9 and $type ne 11 and $type ne 12 and $type ne 0) then
                (: these aren't blocks, unless they're paired :)
                $char 
            else if($type eq 509 and not($buffer = (":",">","<","!"))) then 
                $char
            else
                ()
        else if($stop) then
            string-join(($buffer,$char))
        else
            ()
    let $tpl := 
        if($flag = (2,4,6,7,8,9,10) or $was-number or $was-var) then
            ()
        else if($emit-buffer and exists($buffer) and $xq-compat) then
            xqc:inspect-buf($buffer)
        else
            ()
    let $fix-quot := (exists($tpl) and $tpl("t") eq 7 and $type eq 6)
    let $flag := 
        if($fix-quot) then
            ()
        else
            $flag
    let $fix-quot-and := $fix-quot and $next eq "&quot;"
    let $emit-buffer := if($fix-quot-and) then () else $emit-buffer
    let $tpl := if($fix-quot-and) then () else $tpl
    let $nu := console:log(map {
        "type": $type,
        "old": $old-type,
        "tpl": $tpl,
        "flag": $flag,
        "attrval": $attrval,
        "comment":$comment,
        "char": $char,
        "string": $string,
        "zero": $zero,
        "number": $number,
        "was-num": $was-number,
        "var": $var,
        "was-var":$was-var,
        "buf":$buffer,
        "emit":$emit-buffer
    })
    let $ret :=
        ($ret,$tpl,
            if($flag eq 2) then
                map {
                    "t": xqc:flag-to-expr($flag),
                    "v": if(empty($emit-buffer)) then "" else $emit-buffer
                }
            else if($flag = (4,6,8,9,10)) then
                if($emit-buffer) then
                    map {
                        "t": xqc:flag-to-expr($flag),
                        "v": if($flag eq 8) then 2 else $emit-buffer
                    }
                else
                    ()
            else if($emit-buffer) then
                if($type eq 10 and empty($buffer)) then
                    ()
                else if($flag = (7,11) or head($opencount) gt 0) then
                    map {
                        "t": 7,
                        "v": $emit-buffer
                    }
                else 
                    (
                        if($was-var or ($var and $stop)) then
                            map { "t": 5, "v": $emit-buffer }
                        else if($was-number or ($number and $stop)) then
                            map { "t": 8, "v": $emit-buffer }
                        else
                            (),
                        if($zero) then
                            xqc:inspect-tokens($char,$type)
                        else
                            ()
                    )
            else
                ()
        )
    return if($stop) then
        $ret    
    else
        let $rest := tail($chars)
        return xqc:analyze-chars(
            $ret,
            if($flag eq 4) then tail($rest) else $rest,
            $xq-compat,
            if($flag eq 4) then head($rest) else $next,
            if($type eq 10) then $old-type else $type,
            if($emit-buffer or $attrval or $flag = (2,6,9)) then
                (: TODO never buffer for some flags :)
                ()
            else if($comment and $type eq 2600) then
                (: prevent buffering colons in comments :)
                if(empty($buffer)) then () else if($next eq ")") then $buffer else ($buffer,$char)
            else if($zero and $flag) then
                $buffer
            else
                ($buffer,$char),
            if($fix-quot-and or $attrval) then
                $type
            else if($flag eq 1) then
                $type
            else if($flag eq 2) then
                0
            else
                $string,
            $var,
            $was-qname,
            $number,
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
            if($flag eq 9) then
                true()
            else if($flag eq 10) then
                false()
            else
                $attrkey,
            if($flag eq 10) then
                true()
            else if($attrval and $type eq 6) then
                false()
            else
                $attrval,
            if($flag eq 11) then
                true()
            else if($flag eq 12) then
                false()
            else
                $enc-expr,
            $has-quot,
            if($flag eq 11) then 
                (0,$opencount)
            else if($flag eq 12) then 
                tail($opencount)
            else
                $opencount
        )
};
