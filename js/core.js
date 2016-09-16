import * as raddle from "../content/raddle.xql";

import * as op from "op.xql";

import * as n from "n.xql";

import * as a from "array-util.xql";

import * as console from "http://exist-db.org/xquery/console";

export function elem_3($frame, $name, $content) /*Item*/ {

    return n.element_2($name, $content);

};

export function attr_3($frame, $name, $content) /*Item*/ {

    return n.attribute_2($name, $content);

};

export function text_2($frame, $content) /*Item*/ {

    return n.text_1($content);

};

export function define_6($frame, $name, $desc, $args, $type, $body) /*Item*/ {

    return ($map = new Item(a.foldLeftAt_3($args, {}, function($pre, $_, $i) /*fn.item_0()*/ {

            return $_($frame);

        })),

        map.new_1(($frame, map.entry_2("$functions", {}), map.entry_2("$exports", map.put_4($frame("$exports"), fn.concat_3($name, "#", array.size_1($args)), (n.bind_3($body, $args, $type)($frame)))))));

};

export function describe_5($frame, $name, $desc, $args, $type) /*Item*/ {

    return map.put_3($frame, fn.concat_3($name, "#", array.size_1($args)), {
        "name": $name,
        "description": $desc
    });

};

export function function_3($args, $type, $body) /*Item*/ {

    return n.bind_3($body, $args, $type);

};

export function typecheck_2($type, $val) /*Item*/ {

    return (util.eval_1(fn.concat_2("$val instance of ", $type)) ? console.log_1(($val, $type)) : console.log_1("Not of correct type"));

};

export function getNameSuffix_1($name) /*Item*/ {

    return ($cp = new Item(fn.stringToCodepoints_1($name)),

        ($cpfn.last_0() == 4243456395 ? fn.codepointsToString_1(fn.reverse_1(fn.tail_1(fn.reverse_1($cp)))) : $name));

};

export function typegen_4($frame, $type, $name, $val) /*Item*/ {

    return map.put_3($frame, $name, $val);

};

export function typegen_3($frame, $type, $name) /*Item*/ {

    return function($frame, $val, $i) /*fn.item_0()*/ {

        return ($val = new Item((fn.empty_1($val) ? $type : $val)), map.put_3($frame, ($name == "" ? new String($i) : $name), $val));

    };

};

export function item_0() /*Item*/ {

    return "core:item()";

};

export function item_2($frame, $name) /*Item*/ {

    return $name;

};

export function item_3($frame, $name, $val) /*Item*/ {

    return $$name = new $frame($val);

};

export function integer_0() /*Item*/ {

    return "xs:integer";

};

export function integer_2($frame, $name) /*Item*/ {

    return $name;

};

export function integer_3($frame, $name, $val) /*Item*/ {

    return $$name = new $frame($val);

};

export function string_0() /*Item*/ {

    return "xs:string";

};

export function string_2($frame, $name) /*Item*/ {

    return $name;

};

export function string_3($frame, $name, $val) /*Item*/ {

    return $$name = new $frame($val);

};

export function apply_3($frame, $name, $args) /*Item*/ {

    return ($self = new Item(isCurrentModule_2($frame, $name)),

        $f = new Item(resolveFunction_3($frame, $name, $self)),

        $frame = new Item(map.put_3($frame, "$callstack", array.append_2($frame("$callstack"), $name))),

        $frame = new Item(map.put_3($frame, "$caller", $name)),

        ($self ? $f(processArgs_2($frame, $args)) : fn.apply_2($f, processArgs_2($frame, $args))));

};

function isCurrentModule_2($frame, $name) /*Item*/ {

    return map.contains_2($frame, "$prefix") && fn.matches_2($name, fn.concat_3("^", $frame("$prefix"), ":"));

};

export function resolveFunction_2($frame, $name) /*Item*/ {

    return resolveFunction_3($frame, $name, $self);

};

export function resolveFunction_3($frame, $name, $self) /*Item*/ {

    return ($self ? ($frame("$exports")($name)) : $parts = new Item(fn.tokenize_2($name, ":")), $prefix = new Item((filterAt_2($parts, $_0 == 2) ? filterAt_2($parts, $_0 == 1) : "")), $module = new Item(($frame("$imports")($prefix))), $theirname = new Item(fn.concat_2(($module("$prefix") ? fn.concat_2($module("$prefix"), ":") : ""), $partsfn.last_0())), $module("$exports")($theirname));

};

export function processArgs_2($frame, $args) /*Item*/ {

    return a.forEachAt_2($args, function($arg, $at) /*fn.item_0()*/ {

        return ($arg instance of Item ? $is - params = new Item($frame("$caller") == "core:define#6" && $at == 4 || $frame("$caller") == "core:function#3" && $at == 1), $is - body = new Item($frame("$caller") == "core:define#6" && $at == 6), ($is - params || isFnSeq_1($value) == fn.false_0() && $is - body == fn.false_0() ? a.forEach_2($arg, function($_) /*fn.item_0()*/ {

            return n.eval_1(($_ instance of String && fn.matches_2($_, "^\$") ? {
                "name": "core:item",
                "args": "$",
                fn.replace_3($_, "^\$", "")
            } : $_));

        }) : n.eval_1($arg)) : ($arg instance of Map ? n.eval_1($arg) : ($arg == "." ? $frame("0") : ($arg == "$" ? $frame : (fn.matches_2($arg, fn.concat_3("^\$[", $raddle: ncname, "]+$")) ? $frame(fn.replace_3($arg, "^\$", "")) : (fn.matches_2($arg, fn.concat_5("^[", $raddle: ncname, "]?:?[", $raddle: ncname, "]+#(\p{N}|N)+")) ? resolveFunction_2($frame, $name) : $arg))))));

    });

};

function isFnSeq_1($value) /*Item*/ {

    return (array.size_1($value) == 0 ? nil_0() : fn.distinctValues_1(array.flatten_1(array.forEach_2($value, function($_) /*fn.item_0()*/ {

        return ($_ instance of Map ? isFnSeq_1($value) : $_ instance of String && fn.matches_2($_, "^\.$|^\$$"));

    }))) == fn.true_0());

};

export function import_3($frame, $prefix, $uri) /*Item*/ {

    return import * as $prefix from nil_0();

};

export function import_4($frame, $prefix, $uri, $location) /*Item*/ {

    return ($import = new Item((fn.empty_1($location) || xmldb.getMimeType_2("AnyURI", ($location)) == "application/xquery" ? n.import_1($location) : $src = new Item(util.binaryToString_1(util.binaryDoc_1($location))), n.eval_1(raddle.parse_2($src, $frame))($frame))));

};

export function module_4($frame, $prefix, $ns, $desc) /*Item*/ {

    return map.new_1(($frame, {
        "$prefix": $prefix,
        "$uri": $ns,
        "$description": $desc,
        "$functions": {},
        "$exports": {}
    }));

}
