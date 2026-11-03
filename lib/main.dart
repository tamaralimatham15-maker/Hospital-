import 'package:flutter/material.dart';
void main() => runApp(const CareFlowApp());
class CareFlowApp extends StatefulWidget {
 const CareFlowApp({super.key});
 @override State<CareFlowApp> createState() => _CareFlowAppState();
}
class _CareFlowAppState extends State<CareFlowApp> {
 ThemeMode mode = ThemeMode.light;
 @override Widget build(BuildContext context) => MaterialApp(
  debugShowCheckedModeBanner:false, title:'رِعاية | CareFlow', themeMode:mode,
  theme:ThemeData(colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xff087e8b)),useMaterial3:true),
  darkTheme:ThemeData(colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xff43c6c9),brightness:Brightness.dark),useMaterial3:true),
  home:HomePage(onTheme:()=>setState(()=>mode=mode==ThemeMode.light?ThemeMode.dark:ThemeMode.light)));
}
class HomePage extends StatefulWidget {
 final VoidCallback onTheme; const HomePage({super.key,required this.onTheme});
 @override State<HomePage> createState()=>_HomePageState();
}
class _HomePageState extends State<HomePage> {
 int tab=0;
 final patients=<String>['أحمد علي — ردهة الرجال','محمد حسن — العناية المركزة','زهراء كريم — ردهة النساء'];
 final wards=<String>['ردهة الرجال','ردهة النساء','العناية المركزة','الأطفال'];
 final treatments=<String>['Paracetamol 1 g — IV — 08:00','Ceftriaxone 1 g — IV — 12:00','Normal Saline — IV — 18:00'];
 @override Widget build(BuildContext context) {
  final pages=[dashboard(),listPage('المرضى',patients,Icons.people_alt_outlined,'إضافة مريض'),listPage('الردهات والأقسام',wards,Icons.local_hospital_outlined,'إضافة ردهة'),listPage('جدول العلاجات',treatments,Icons.medication_outlined,'إضافة علاج'),settingsPage()];
  return Directionality(textDirection:TextDirection.rtl,child:Scaffold(
   appBar:AppBar(title:const Row(children:[Icon(Icons.health_and_safety,color:Color(0xff087e8b)),SizedBox(width:9),Text('رِعاية',style:TextStyle(fontWeight:FontWeight.bold)),SizedBox(width:8),Text('CareFlow',style:TextStyle(fontSize:13))]),actions:[IconButton(onPressed:widget.onTheme,icon:const Icon(Icons.brightness_6_outlined))]),
   body:SafeArea(child:pages[tab]),
   bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const[
    NavigationDestination(icon:Icon(Icons.dashboard_outlined),label:'الرئيسية'),
    NavigationDestination(icon:Icon(Icons.people_outline),label:'المرضى'),
    NavigationDestination(icon:Icon(Icons.apartment_outlined),label:'الردهات'),
    NavigationDestination(icon:Icon(Icons.medication_outlined),label:'العلاجات'),
    NavigationDestination(icon:Icon(Icons.settings_outlined),label:'الإعدادات')])));
 }
 Widget dashboard()=>ListView(padding:const EdgeInsets.all(16),children:[
  Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(borderRadius:BorderRadius.circular(22),gradient:const LinearGradient(colors:[Color(0xff087e8b),Color(0xff155e75)])),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Text('مرحباً بك في رِعاية',style:TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.bold)),SizedBox(height:8),
   Text('نظام تجريبي لتنظيم العمل داخل المؤسسة الصحية',style:TextStyle(color:Colors.white70)),SizedBox(height:16),
   Row(children:[Icon(Icons.shield_outlined,color:Colors.white),SizedBox(width:8),Text('بيئة تجريبية — بيانات وهمية',style:TextStyle(color:Colors.white))])])),
  const SizedBox(height:18),
  GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:2,crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:1.45,children:[
   statCard('المرضى',patients.length.toString(),Icons.people_alt_outlined),statCard('الردهات',wards.length.toString(),Icons.apartment),
   statCard('العلاجات المجدولة',treatments.length.toString(),Icons.medication_outlined),statCard('تنبيهات اليوم','2',Icons.notifications_active_outlined)]),
  const SizedBox(height:18),const Text('آخر المرضى',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
  ...patients.map((p)=>Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.person_outline)),title:Text(p),subtitle:const Text('ملف تجريبي'))))]);
 Widget statCard(String title,String value,IconData icon)=>Card(elevation:0,color:Theme.of(context).colorScheme.surfaceContainerHighest,child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Icon(icon,color:const Color(0xff087e8b)),Text(value,style:const TextStyle(fontSize:25,fontWeight:FontWeight.bold)),Text(title,style:const TextStyle(fontSize:13))])));
 Widget listPage(String title,List<String> items,IconData icon,String action)=>ListView(padding:const EdgeInsets.all(16),children:[
  Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(title,style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),FilledButton.icon(onPressed:()=>addItem(title,items),icon:const Icon(Icons.add),label:Text(action))]),
  const SizedBox(height:12),...items.map((item)=>Card(child:ListTile(leading:CircleAvatar(child:Icon(icon)),title:Text(item),subtitle:const Text('بيانات للعرض فقط'),trailing:const Icon(Icons.chevron_left))))]);
 void addItem(String title,List<String> items){
  final controller=TextEditingController();
  showDialog(context:context,builder:(ctx)=>AlertDialog(title:Text('إضافة إلى $title'),content:TextField(controller:controller,autofocus:true,decoration:const InputDecoration(hintText:'اكتب الاسم أو التفاصيل')),actions:[
   TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),
   FilledButton(onPressed:(){if(controller.text.trim().isNotEmpty)setState(()=>items.add(controller.text.trim()));Navigator.pop(ctx);},child:const Text('إضافة'))]));
 }
 Widget settingsPage()=>ListView(padding:const EdgeInsets.all(16),children:[
  const Text('الإعدادات',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),const SizedBox(height:12),
  const Card(child:ListTile(leading:Icon(Icons.business_outlined),title:Text('المؤسسة الصحية'),subtitle:Text('مؤسسة تجريبية'))),
  const Card(child:ListTile(leading:Icon(Icons.admin_panel_settings_outlined),title:Text('إدارة الصلاحيات'),subtitle:Text('ستتوفر عند ربط الخادم'))),
  const Card(child:ListTile(leading:Icon(Icons.cloud_outlined),title:Text('قاعدة البيانات'),subtitle:Text('غير متصلة — البيانات محلية مؤقتة'))),
  const Card(child:ListTile(leading:Icon(Icons.info_outline),title:Text('حول التطبيق'),subtitle:Text('CareFlow Prototype 0.1.0'))),
  const Padding(padding:EdgeInsets.all(12),child:Text('تنبيه: هذه نسخة واجهة تجريبية فقط. لا تستخدمها لتسجيل بيانات مرضى حقيقية أو لاتخاذ قرارات علاجية.',style:TextStyle(color:Colors.orange)))]);
}
