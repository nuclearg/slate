(function () {
  var out = [];
  function p(label, value) { out.push("T|" + label + "|" + String(value)); }
  function t(label, fn) { try { p(label, fn()); } catch (e) { p(label, "EX:" + String(e && e.message ? e.message : e)); } }

  t("num.div", function () { return 1/3; });
  t("num.01", function () { return 0.1+0.2; });
  t("num.big", function () { return Math.pow(2,53)+1; });
  t("num.negzero", function () { return String(-0); });
  t("num.inf", function () { return 1/0; });
  t("num.nan", function () { return 0/0; });
  t("num.1e21", function () { return 1e21; });
  t("num.hex", function () { return 0x10; });
  t("bit.shift", function () { return (1<<31); });
  t("bit.ushift", function () { return (1<<31)>>>0; });
  t("parse.i", function () { return parseInt("08", 10) + parseInt("0x10", 16); });
  t("parse.f", function () { return parseFloat("1.5e3"); });
  t("str.len", function () { return "é😀".length; });
  t("str.code", function () { return "a".charCodeAt(0); });
  t("str.add", function () { return "a"+1; });
  t("str.esc", function () { return "\u00e9\u4e2d"; });
  t("json.str", function () { return JSON.stringify({b:1,a:[2,{c:3}]}); });
  t("json.parse", function () { return JSON.parse('{"z":1}').z; });
  t("json.err", function () { try { JSON.parse("{"); } catch(e) { return e.name; } });
  t("obj.keys", function () { return Object.keys({x:1,y:2}).join(","); });
  t("arr.sort", function () { return [10,2,1].sort().join(","); });
  t("arr.map", function () { return [1,2,3].map(function(x){return x*2;}).join(","); });
  t("arr.join", function () { return [1,null,undefined,2].join(","); });
  t("und.isArray", function () { return _.isArray([]); });
  t("und.isObjectNull", function () { return _.isObject(null); });
  t("und.map", function () { return _.map([1,2,3], function(x){return x+1;}).join(","); });
  t("re.replace", function () { return "a1b2".replace(/\d/g,"#"); });
  t("re.exec", function () { return /(a)(b)/.exec("ab").join("|"); });
  t("typeof.undef", function () { return typeof undefined; });
  t("typeof.null", function () { return typeof null; });
  t("typeof.fn", function () { return typeof function(){}; });
  t("args.len", function () { return (function(){return arguments.length;})(1,2,3); });
  t("date.utc", function () { return Date.UTC(1970,0,1); });
  t("encode", function () { return encodeURIComponent("a b&c"); });
  t("isnan", function () { return isNaN("x"); });
  t("eval", function () { return eval("1+2"); });
  t("this.window", function () { return this === window; });
  t("closure", function () { var n=0; var f=function(){return ++n;}; f(); return f(); });
  t("proto", function () { function A(){}; A.prototype.x=1; return (new A()).x; });
  t("obj.tostr", function () { return ({}).toString(); });
  t("arr.concat", function () { return [].concat(1,[2,3]).length; });
  t("str.substr", function () { return "abcdef".substr(2,3); });
  t("nan.eq", function () { return NaN === NaN; });
  t("null.loose", function () { return null == undefined; });
  t("null.strict", function () { return null === undefined; });
  t("switch", function () { var r=""; switch(2){case 1:r="a";break;case 2:r="b";break;default:r="c";} return r; });
  t("try.finally", function () { var r=""; try { r+="a"; } finally { r+="b"; } return r; });
  t("info.screens", function () { return slate.info.screenCount(); });
  t("info.each", function () { var n=0; slate.info.eachScreen(function(s){ n++; }); return n; });
  t("screen.rect", function () { var r=""; slate.info.eachScreen(function(s){ if(r===""){ r=JSON.stringify(s.rect()); } }); return r; });
  t("op.type", function () { return typeof slate.operation("resize"); });
  t("src.bad", function () { return slate.source("/nonexistent-xyz"); });
  t("cfg.get", function () { return slate.info.defaultToCurrentScreen ? "has" : "missing"; });

  t("screen.main", function () { return slate.info.screen().main(); });
  t("screen.isMain", function () { return slate.info.screen().isMain(); });
  t("screen.id.type", function () { return typeof slate.info.screen().id(); });
  t("rect.off", function () { return slate.info.isRectOffScreen({x:-99999,y:-99999,width:10,height:10}); });
  t("rect.on", function () { return slate.info.isRectOffScreen({x:0,y:0,width:10,height:10}); });
  t("pnt.off", function () { return slate.info.isPointOffScreen({x:100,y:100}); });
  t("pnt.far", function () { return slate.info.isPointOffScreen({x:99999,y:99999}); });
  t("typeof.rectoff", function () { return typeof slate.info.isRectOffScreen({x:0,y:0,width:1,height:1}); });

  t("sh.out", function () { return slate.sh("/usr/bin/printf abc", true); });
  t("sh.merge", function () { return slate.sh("/bin/sh -c 'printf out; printf err 1>&2'", true); });
  t("sh.empty", function () { return slate.sh("/usr/bin/false", true); });
  t("sh.nowait", function () { return String(slate.sh("/usr/bin/true", false)); });
  t("sh.typeof", function () { return typeof slate.sh("/usr/bin/printf x", true); });

  slate.log("BEGIN\n" + out.join("\n") + "\nEND");
})();
