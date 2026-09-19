import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const pink = Color(0xFFFF4F91);
const purple = Color(0xFF8B5CF6);
const bg = Color(0xFF090711);
const panel = Color(0xCC171323);

void main() => runApp(const LoveCompatApp());

enum Lang { ru, en }
enum Screen { home, calculating, result, about, support }

class Txt {
  final String subtitle, enterNames, firstName, secondName, calculate, entertainment;
  final String back, result, compatibility, parameters, love, attraction, communication;
  final String understanding, emotional, checkAnother, deterministic, home, about, support;
  final String language, supportBody, writeEmail, emailSubject, enterBoth, addPhotos, samePhoto;
  final String calculationSubtitle;
  const Txt({required this.subtitle, required this.enterNames, required this.firstName,
    required this.secondName, required this.calculate, required this.entertainment,
    required this.back, required this.result, required this.compatibility, required this.parameters,
    required this.love, required this.attraction, required this.communication, required this.understanding,
    required this.emotional, required this.checkAnother, required this.deterministic, required this.home,
    required this.about, required this.support, required this.language, required this.supportBody,
    required this.writeEmail, required this.emailSubject, required this.enterBoth, required this.addPhotos,
    required this.samePhoto, required this.calculationSubtitle});
}

const ru = Txt(
  subtitle: 'Тест совместимости для двоих', enterNames: 'Введите имена', firstName: 'Имя первого человека',
  secondName: 'Имя второго человека', calculate: '♥  Рассчитать совместимость',
  entertainment: 'Развлекательный тест. Результат не является научной оценкой отношений.', back: 'Назад',
  result: 'Результат', compatibility: 'совместимость', parameters: 'Параметры', love: 'Любовь',
  attraction: 'Притяжение', communication: 'Общение', understanding: 'Понимание', emotional: 'Эмоциональная связь',
  checkAnother: 'Проверить другую пару', deterministic: 'Один и тот же набор имён и фото даёт один и тот же результат независимо от порядка ввода.',
  home: 'Главная', about: 'О версии', support: 'Поддержка', language: 'Язык',
  supportBody: 'Если у вас есть вопрос или предложение, напишите в службу поддержки.',
  writeEmail: 'Написать на почту', emailSubject: 'LoveCompat — сообщение поддержки', enterBoth: 'Введите оба имени',
  addPhotos: 'Добавьте две фотографии',
  samePhoto: 'Похоже, выбрана одна и та же фотография для обоих. Пожалуйста, выберите две разные фотографии.',
  calculationSubtitle: 'Анализируем имена и фотографии');

const en = Txt(
  subtitle: 'Compatibility test for two', enterNames: 'Enter names', firstName: "First person's name",
  secondName: "Second person's name", calculate: '♥  Calculate compatibility',
  entertainment: 'Entertainment test. The result is not a scientific assessment of relationships.', back: 'Back',
  result: 'Result', compatibility: 'compatibility', parameters: 'Parameters', love: 'Love', attraction: 'Attraction',
  communication: 'Communication', understanding: 'Understanding', emotional: 'Emotional connection',
  checkAnother: 'Check another pair', deterministic: 'The same names and photos always give the same result regardless of input order.',
  home: 'Home', about: 'About', support: 'Support', language: 'Language',
  supportBody: 'If you have a question or suggestion, contact support.', writeEmail: 'Write by email',
  emailSubject: 'LoveCompat — support message', enterBoth: 'Enter both names', addPhotos: 'Add two photos',
  samePhoto: 'It looks like the same photo was selected for both people. Please choose two different photos.',
  calculationSubtitle: 'Analyzing names and photos');

Txt t(Lang l) => l == Lang.ru ? ru : en;

class ResultData {
  final int score, love, attraction, communication, understanding, emotional;
  const ResultData(this.score, this.love, this.attraction, this.communication, this.understanding, this.emotional);
}

String normalizeName(String s) => s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

String hashBytes(Uint8List bytes) => sha256.convert(bytes).toString();

ResultData stableScore(String a, String h1, String b, String h2) {
  final first = '${normalizeName(a)}:$h1';
  final second = '${normalizeName(b)}:$h2';
  final parts = [first, second]..sort();
  final digest = sha256.convert(utf8.encode('${parts[0]}|${parts[1]}')).bytes;
  BigInt seed = BigInt.zero;
  for (final byte in digest.take(8)) seed = (seed << 8) | BigInt.from(byte);
  final positive = seed & BigInt.parse('7fffffffffffffff', radix: 16);
  final score = (positive % BigInt.from(101)).toInt();
  int sub(int offset, int spread) {
    final value = ((positive >> offset) & BigInt.from(0x3f)).toInt();
    final delta = (value % (spread * 2 + 1)) - spread;
    return (score + delta).clamp(0, 100);
  }
  return ResultData(score, sub(1,13), sub(7,15), sub(13,12), sub(19,14), sub(25,16));
}

String level(int s, Lang l) => l == Lang.ru
    ? (s <= 19 ? 'Очень низкая совместимость' : s <= 39 ? 'Низкая совместимость' : s <= 59 ? 'Средняя совместимость' : s <= 79 ? 'Хорошая совместимость' : s <= 94 ? 'Очень хорошая совместимость' : 'Исключительная совместимость')
    : (s <= 19 ? 'Very low compatibility' : s <= 39 ? 'Low compatibility' : s <= 59 ? 'Average compatibility' : s <= 79 ? 'Good compatibility' : s <= 94 ? 'Very good compatibility' : 'Exceptional compatibility');

String description(int s, Lang l) => l == Lang.ru
    ? (s <= 19 ? 'По этому развлекательному тесту у вас много различий. Взаимопонимание может требовать больше усилий.' : s <= 39 ? 'Результат показывает заметные различия. Хорошее общение здесь особенно важно.' : s <= 59 ? 'Есть и совпадения, и различия. Результат находится примерно посередине.' : s <= 79 ? 'Тест показывает хороший уровень совпадений и приятный потенциал для общения.' : s <= 94 ? 'Много совпадений по параметрам этого теста — сочетание получилось сильным.' : 'По параметрам теста совпадений очень много. Получился редкий результат.')
    : (s <= 19 ? 'This entertainment test shows many differences. Understanding each other may require more effort.' : s <= 39 ? 'The result shows noticeable differences. Good communication is especially important here.' : s <= 59 ? 'There are both similarities and differences. The result is around the middle.' : s <= 79 ? 'The test shows a good level of similarities and pleasant potential for communication.' : s <= 94 ? 'There are many matches across the test parameters — the combination turned out strong.' : 'There are very many matches across the test parameters. This is a rare result.');

class LoveCompatApp extends StatefulWidget { const LoveCompatApp({super.key}); @override State<LoveCompatApp> createState() => _AppState(); }
class _AppState extends State<LoveCompatApp> {
  Lang lang = Lang.ru; Screen screen = Screen.home; bool menu = false; String error = '';
  String firstName='', secondName=''; XFile? firstPhoto, secondPhoto; ResultData? result;
  final picker = ImagePicker();

  @override void initState() { super.initState(); _loadLang(); }
  Future<void> _loadLang() async { final p=await SharedPreferences.getInstance(); if(mounted)setState(()=>lang=p.getString('lang')=='en'?Lang.en:Lang.ru); }
  Future<void> _toggleLang() async { final next=lang==Lang.ru?Lang.en:Lang.ru; final p=await SharedPreferences.getInstance(); await p.setString('lang', next==Lang.en?'en':'ru'); if(mounted)setState(()=>lang=next); }
  Future<void> _pick(bool first) async { final x=await picker.pickImage(source: ImageSource.gallery); if(x!=null&&mounted)setState(()=>first?firstPhoto=x:secondPhoto=x); }
  Future<String> _photoHash(XFile x) async => hashBytes(await x.readAsBytes());
  Future<void> _calculate() async {
    final tx=t(lang); if(firstName.trim().isEmpty||secondName.trim().isEmpty){setState(()=>error=tx.enterBoth);return;}
    if(firstPhoto==null||secondPhoto==null){setState(()=>error=tx.addPhotos);return;}
    final h1=await _photoHash(firstPhoto!), h2=await _photoHash(secondPhoto!);
    if(h1==h2){setState(()=>error=tx.samePhoto);return;}
    setState(() { error = ''; screen = Screen.calculating; });
    await Future.delayed(const Duration(milliseconds:11800));
    if(!mounted)return; setState(() { result = stableScore(firstName, h1, secondName, h2); screen = Screen.result; });
  }
  void reset(){setState(() { firstName=''; secondName=''; firstPhoto=null; secondPhoto=null; result=null; error=''; screen=Screen.home; menu=false; });}
  @override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false,theme:ThemeData.dark(useMaterial3:true,scaffoldBackgroundColor:bg,fontFamily:'sans-serif'),home:Scaffold(body:Stack(children:[const Background(), AnimatedSwitcher(duration:const Duration(milliseconds:650),transitionBuilder:(c,a)=>FadeTransition(opacity:a,child:ScaleTransition(scale:Tween(begin:.985,end:1).animate(a),child:c)),child:_page())])));
  Widget _page(){switch(screen){case Screen.home:return Home(key:const ValueKey('home'),state:this);case Screen.calculating:return Calculating(key:const ValueKey('calc'),lang:lang);case Screen.result:return ResultScreen(key:const ValueKey('result'),lang:lang,first:firstName,second:secondName,p1:firstPhoto,p2:secondPhoto,data:result!,onBack:()=>setState(()=>screen=Screen.home),onReset:reset);case Screen.about:return Info(key:const ValueKey('about'),title:t(lang).about,back:t(lang).back,body:lang==Lang.ru?'Версия 2.0\n\nЧто нового в 2.0\n\n• Плавные переходы и анимации\n• Яркие плавающие смайлики на фоне\n• Русский и английский языки\n• Обновлённый главный экран\n• Проверка на одинаковые фотографии\n• Улучшенная структура приложения\n\nLoveCompat создан для лёгкого и приятного развлечения.':'Version 2.0\n\nWhat’s new in 2.0\n\n• Smooth transitions and animations\n• Bright floating emojis in the background\n• Russian and English languages\n• Updated home screen\n• Duplicate-photo check\n• Improved app structure\n\nLoveCompat is made for light and enjoyable fun.',onBack:()=>setState(()=>screen=Screen.home));case Screen.support:return Support(key:const ValueKey('support'),lang:lang,onBack:()=>setState(()=>screen=Screen.home));}}
}

class Background extends StatefulWidget{const Background({super.key});@override State<Background> createState()=>_BackgroundState();}
class _BackgroundState extends State<Background> with SingleTickerProviderStateMixin{late AnimationController c;final emojis=['♥','💕','💖','✨','😍','🥰','💗','💘','💝','💫','🌸','❤️','💞','😘','⭐'];@override void initState(){super.initState();c=AnimationController(vsync:this,duration:const Duration(seconds:11))..repeat();}@override void dispose(){c.dispose();super.dispose();}@override Widget build(BuildContext context)=>IgnorePointer(child:ClipRect(child:AnimatedBuilder(animation:c,builder:(_,__)=>Stack(children:[for(int i=0;i<emojis.length;i++)_emoji(i,emojis[i],c.value)]))));Widget _emoji(int i,String e,double p){final seed=math.sin(i*91.7)*10000;final r=seed-seed.floorToDouble();final startX=(.04+(.92*r));final drift=(i.isEven?1:-1)*(.10+.18*((i*37)%10)/10);final x=(startX+drift*math.sin(p*2*math.pi+(i%4))).clamp(-.1,1.1).toDouble();final y=1.15-(p*1.35);final fade=(math.sin(p*math.pi)).clamp(0.0,1.0);return Positioned(left:MediaQuery.sizeOf(context).width*x,top:MediaQuery.sizeOf(context).height*y,child:Opacity(opacity:.65*fade,child:Transform.rotate(angle:(i.isEven?1:-1)*.25*math.sin(p*2*math.pi+i),child:Text(e,style:TextStyle(fontSize:20+(i%5)*5)))));}}

class Home extends StatelessWidget{final _AppState state;const Home({super.key,required this.state});@override Widget build(BuildContext c){final tx=t(state.lang);return SafeArea(child:SingleChildScrollView(padding:const EdgeInsets.fromLTRB(22,18,22,26),child:Column(children:[Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[CircleButton(icon:'☰',onTap:()=>state.setState(()=>state.menu=!state.menu)),const Text('♥',style:TextStyle(color:pink,fontSize:42,fontWeight:FontWeight.bold)),CircleButton(icon:'文',onTap:state._toggleLang)]),if(state.menu)Card(color:panel,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)),child:Column(children:[MenuItem(text:tx.about,onTap:()=>state.setState(() { state.menu=false; state.screen=Screen.about; })),MenuItem(text:tx.support,onTap:()=>state.setState(() { state.menu=false; state.screen=Screen.support; }))])),const SizedBox(height:8),const Text('LoveCompat',style:TextStyle(fontSize:34,fontWeight:FontWeight.w900)),Text(tx.subtitle,style:const TextStyle(color:Color(0xFFBDB5CA),fontSize:14)),const SizedBox(height:30),Card(color:panel,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(28)),child:Padding(padding:const EdgeInsets.all(20),child:Column(children:[Row(children:[Expanded(child:PhotoPicker(x:state.firstPhoto,name:state.firstName.isEmpty?(state.lang==Lang.ru?'Вы':'You'):state.firstName,lang:state.lang,onTap:()=>state._pick(true))),SizedBox(width:36,child:Padding(padding:const EdgeInsets.only(bottom:28),child:Center(child:Text('×',style:TextStyle(color:pink,fontSize:40,fontWeight:FontWeight.w900))))),Expanded(child:PhotoPicker(x:state.secondPhoto,name:state.secondName.isEmpty?(state.lang==Lang.ru?'Партнёр':'Partner'):state.secondName,lang:state.lang,onTap:()=>state._pick(false)))]),const SizedBox(height:22),Align(alignment:Alignment.centerLeft,child:Text(tx.enterNames,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:17))),const SizedBox(height:12),NameField(value:state.firstName,label:tx.firstName,onChanged:(v)=>state.setState(()=>state.firstName=v)),const SizedBox(height:12),NameField(value:state.secondName,label:tx.secondName,onChanged:(v)=>state.setState(()=>state.secondName=v)),if(state.error.isNotEmpty)Padding(padding:const EdgeInsets.only(top:10),child:Text(state.error,textAlign:TextAlign.center,style:const TextStyle(color:Color(0xFFFF8EA9),fontSize:13))),const SizedBox(height:20),SizedBox(width:double.infinity,height:58,child:ElevatedButton(onPressed:state._calculate,style:ElevatedButton.styleFrom(backgroundColor:pink,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18))),child:Text(tx.calculate,style:const TextStyle(fontWeight:FontWeight.bold))))])),const SizedBox(height:16),Text(tx.entertainment,textAlign:TextAlign.center,style:const TextStyle(color:Color(0xFF82798F),fontSize:11))]));}}

class CircleButton extends StatelessWidget{final String icon;final VoidCallback onTap;const CircleButton({super.key,required this.icon,required this.onTap});@override Widget build(BuildContext c)=>Material(color:const Color(0xCC171323),shape:const CircleBorder(side:BorderSide(color:Color(0xFF6D5A88))),child:InkWell(customBorder:const CircleBorder(),onTap:onTap,child:SizedBox(width:44,height:44,child:Center(child:Text(icon,style:const TextStyle(color:Colors.white,fontSize:21))))));}
class MenuItem extends StatelessWidget{final String text;final VoidCallback onTap;const MenuItem({super.key,required this.text,required this.onTap});@override Widget build(BuildContext c)=>InkWell(onTap:onTap,child:Container(width:double.infinity,padding:const EdgeInsets.all(16),child:Text(text,style:const TextStyle(color:Colors.white,fontSize:16))));}
class NameField extends StatelessWidget{final String value,label;final ValueChanged<String> onChanged;const NameField({super.key,required this.value,required this.label,required this.onChanged});@override Widget build(BuildContext c)=>TextField(controller:TextEditingController(text:value)..selection=TextSelection.collapsed(offset:value.length),onChanged:onChanged,style:const TextStyle(color:Colors.white),decoration:InputDecoration(labelText:label,labelStyle:const TextStyle(color:Color(0xFFBDB5CA)),filled:true,fillColor:Color(0xFF211C30),border:OutlineInputBorder(borderRadius:BorderRadius.all(Radius.circular(18)),borderSide:BorderSide.none),focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.all(Radius.circular(18)),borderSide:BorderSide.none)));}

class PhotoPicker extends StatelessWidget{final XFile? x;final String name;final Lang lang;final VoidCallback onTap;const PhotoPicker({super.key,required this.x,required this.name,required this.lang,required this.onTap});@override Widget build(BuildContext c)=>Column(children:[GestureDetector(onTap:onTap,child:ClipOval(child:Container(width:112,height:112,color:const Color(0xFF252238),child:x==null?Center(child:Text(lang==Lang.ru?'＋\nФото':'＋\nPhoto',textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontSize:17))):FileImagePlaceholder(x!)))),const SizedBox(height:10),SizedBox(width:112,child:Text(name,maxLines:1,overflow:TextOverflow.ellipsis,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w600))) ]);}

class FileImagePlaceholder extends StatelessWidget{final XFile x;const FileImagePlaceholder(this.x,{super.key});@override Widget build(BuildContext c)=>FutureBuilder<Uint8List>(future:x.readAsBytes(),builder:(_,s)=>s.hasData?Image.memory(s.data!,fit:BoxFit.cover):const SizedBox.shrink());}

class Calculating extends StatefulWidget{final Lang lang;const Calculating({super.key,required this.lang});@override State<Calculating> createState()=>_CalcState();}
class _CalcState extends State<Calculating>{int step=0;Timer? timer; final ruS=['Настраиваем связь…','Сравниваем характеры…','Ищем совпадения…','Проверяем взаимопонимание…','Анализируем притяжение…','Сверяем ваши параметры…','Почти готово…','Формируем результат…'];final enS=['Connecting…','Comparing personalities…','Looking for matches…','Checking understanding…','Analyzing attraction…','Comparing your parameters…','Almost ready…','Preparing the result…'];@override void initState(){super.initState();timer=Timer.periodic(const Duration(milliseconds:1450),(timer){if(!mounted||step>=7){timer.cancel();return;}setState(()=>step++);});}@override void dispose(){timer?.cancel();super.dispose();}@override Widget build(BuildContext c){final s=widget.lang==Lang.ru?ruS:enS;return Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[const SizedBox(width:180,height:180,child:Center(child:Icon(Icons.favorite,color:Colors.white,size:38))),const SizedBox(height:30),AnimatedSwitcher(duration:const Duration(milliseconds:350),child:Text(s[step],key:ValueKey(step),textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.bold))),const SizedBox(height:10),Text(t(widget.lang).calculationSubtitle,style:const TextStyle(color:Color(0xFFAAA1B6),fontSize:14))]));}}

class ResultScreen extends StatefulWidget{final Lang lang;final String first,second;final XFile? p1,p2;final ResultData data;final VoidCallback onBack,onReset;const ResultScreen({super.key,required this.lang,required this.first,required this.second,required this.p1,required this.p2,required this.data,required this.onBack,required this.onReset});@override State<ResultScreen> createState()=>_ResultState();}
class _ResultState extends State<ResultScreen>{int stage=0;@override void initState(){super.initState();_run();}Future<void>_run()async{for(final d in [250,500,450,450,500,500,500,500,500,650]){await Future.delayed(Duration(milliseconds:d));if(mounted)setState(()=>stage++);}}@override Widget build(BuildContext c){final tx=t(widget.lang);return SafeArea(child:ListView(padding:const EdgeInsets.fromLTRB(22,18,22,36),children:[AnimatedItem(show:stage>=1,child:Row(children:[OutlinedButton(onPressed:widget.onBack,child:Text(tx.back)),const SizedBox(width:12),Text(tx.result,style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold))])),const SizedBox(height:18),AnimatedItem(show:stage>=1,child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[SmallPhoto(widget.p1),const Padding(padding:EdgeInsets.symmetric(horizontal:14),child:Text('♥',style:TextStyle(color:pink,fontSize:26))),SmallPhoto(widget.p2)])),const SizedBox(height:8),Text('${widget.first}  ×  ${widget.second}',textAlign:TextAlign.center,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w600)),const SizedBox(height:18),ScoreCard(score:widget.data.score,show:stage>=2,tx:tx),const SizedBox(height:16),AnimatedItem(show:stage>=3,child:Text(level(widget.data.score,widget.lang),textAlign:TextAlign.center,style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold))),const SizedBox(height:10),AnimatedItem(show:stage>=4,child:Card(color:panel,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22)),child:Padding(padding:const EdgeInsets.all(20),child:Text(description(widget.data.score,widget.lang),textAlign:TextAlign.center,style:const TextStyle(color:Color(0xFFD7D0DF),fontSize:15,height:1.45))))),const SizedBox(height:20),AnimatedItem(show:stage>=5,child:Card(color:panel,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22)),child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(tx.parameters,style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),Metric(label:'♥ ${tx.love}',value:widget.data.love,show:stage>=5),Metric(label:'🔥 ${tx.attraction}',value:widget.data.attraction,show:stage>=6),Metric(label:'💬 ${tx.communication}',value:widget.data.communication,show:stage>=7),Metric(label:'🤝 ${tx.understanding}',value:widget.data.understanding,show:stage>=8),Metric(label:'✨ ${tx.emotional}',value:widget.data.emotional,show:stage>=9)]))),const SizedBox(height:20),AnimatedItem(show:stage>=10,child:SizedBox(height:54,child:ElevatedButton(onPressed:widget.onReset,style:ElevatedButton.styleFrom(backgroundColor:pink,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18))),child:Text(tx.checkAnother))))]));}}

class AnimatedItem extends StatelessWidget{final bool show;final Widget child;const AnimatedItem({super.key,required this.show,required this.child});@override Widget build(BuildContext c)=>AnimatedOpacity(opacity:show?1:0,duration:const Duration(milliseconds:500),child:AnimatedScale(scale:show?1:.94,duration:const Duration(milliseconds:560),child:child));}
class ScoreCard extends StatefulWidget{final int score;final bool show;final Txt tx;const ScoreCard({super.key,required this.score,required this.show,required this.tx});@override State<ScoreCard> createState()=>_ScoreState();}
class _ScoreState extends State<ScoreCard> with SingleTickerProviderStateMixin{late AnimationController c;@override void initState(){super.initState();c=AnimationController(vsync:this,duration:const Duration(seconds:3));}@override void didUpdateWidget(covariant ScoreCard old){super.didUpdateWidget(old);if(widget.show&&!old.show)c.forward();}@override void dispose(){c.dispose();super.dispose();}@override Widget build(BuildContext cxt)=>AnimatedOpacity(opacity:widget.show?1:0,duration:const Duration(milliseconds:520),child:Card(color:panel,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(28)),child:Padding(padding:const EdgeInsets.symmetric(vertical:28),child:Center(child:AnimatedBuilder(animation:c,builder:(_,__)=>Text('${(widget.score*c.value).round()}%',style:const TextStyle(fontSize:58,fontWeight:FontWeight.w900,color:pink))))));}
class Metric extends StatelessWidget{final String label;final int value;final bool show;const Metric({super.key,required this.label,required this.value,required this.show});@override Widget build(BuildContext c)=>TweenAnimationBuilder<double>(tween:Tween(begin:0,end:show?1:0),duration:const Duration(milliseconds:1050),builder:(_,v,__){final n=(value*v).round();return Padding(padding:const EdgeInsets.symmetric(vertical:7),child:Column(children:[Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(label,style:const TextStyle(color:Color(0xFFE9E3F1),fontSize:14)),Text('$n%',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14))]),const SizedBox(height:6),ClipRRect(borderRadius:BorderRadius.circular(50),child:LinearProgressIndicator(value:v*value/100,minHeight:7,backgroundColor:Color(0xFF2A253B),valueColor:const AlwaysStoppedAnimation(pink)))]));});}
class SmallPhoto extends StatelessWidget{final XFile? x;const SmallPhoto(this.x,{super.key});@override Widget build(BuildContext c)=>ClipOval(child:Container(width:54,height:54,color:const Color(0xFF29233A),child:x==null?const Text('+'):FileImagePlaceholder(x!)));}

class Info extends StatelessWidget{final String title,body;final VoidCallback onBack;final String back;const Info({super.key,required this.title,required this.body,required this.onBack,required this.back});@override Widget build(BuildContext c)=>SafeArea(child:ListView(padding:const EdgeInsets.fromLTRB(22,18,22,30),children:[Row(children:[OutlinedButton(onPressed:onBack,child:Text(back)),const SizedBox(width:12),Text(title,style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold))]),const SizedBox(height:28),Card(color:panel,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24)),child:Padding(padding:const EdgeInsets.all(22),child:Text(body,textAlign:TextAlign.center,style:const TextStyle(color:Color(0xFFD7D0DF),fontSize:16,height:1.5))))]));}
class Support extends StatelessWidget{final Lang lang;final VoidCallback onBack;const Support({super.key,required this.lang,required this.onBack});@override Widget build(BuildContext c){final tx=t(lang);return SafeArea(child:ListView(padding:const EdgeInsets.fromLTRB(22,18,22,30),children:[Row(children:[OutlinedButton(onPressed:onBack,child:Text(tx.back)),const SizedBox(width:12),Text(tx.support,style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold))]),const SizedBox(height:28),Card(color:panel,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24)),child:Padding(padding:const EdgeInsets.all(22),child:Column(children:[Text(tx.supportBody,textAlign:TextAlign.center,style:const TextStyle(color:Color(0xFFD7D0DF),fontSize:16,height:1.5)),const SizedBox(height:20),SizedBox(width:double.infinity,height:54,child:ElevatedButton(onPressed:()=>launchUrl(Uri.parse('mailto:lovecompat.v2.0@gmail.com?subject=${Uri.encodeComponent(tx.emailSubject)}')),style:ElevatedButton.styleFrom(backgroundColor:pink,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18))),child:Text(tx.writeEmail))),const SizedBox(height:12),const Text('lovecompat.v2.0@gmail.com',style:TextStyle(color:Color(0xFF8E8499),fontSize:11))]))]));}}
