import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
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
 final picker=ImagePicker();
 final notices=FlutterLocalNotificationsPlugin();
 final photosByPatient=<String,List<Map<String,String>>>{};
 bool initialized=false;
 final patients=<String>['أحمد علي — ردهة الرجال','محمد حسن — العناية المركزة','زهراء كريم — ردهة النساء'];
 final wards=<String>['ردهة الرجال','ردهة النساء','العناية المركزة','الأطفال'];
 final patientInfo=<String,Map<String,String>>{};
 final vitalSigns=<String,List<String>>{};
 final nursingNotes=<String,List<String>>{};
 final investigations=<String,List<String>>{};
 final treatmentsByPatient=<String,List<String>>{
  'أحمد علي — ردهة الرجال':['Paracetamol 1 g — IV — 08:00','Normal Saline — IV — 18:00'],
  'محمد حسن — العناية المركزة':['Ceftriaxone 1 g — IV — 12:00'],
  'زهراء كريم — ردهة النساء':[],
 };
 @override void initState(){super.initState();initializeCareFlow();}
 Future<void> initializeCareFlow() async {
  tzdata.initializeTimeZones(); tz.setLocalLocation(tz.getLocation('Asia/Baghdad'));
  await notices.initialize(const InitializationSettings(android:AndroidInitializationSettings('@mipmap/ic_launcher')));
  final a=notices.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await a?.requestNotificationsPermission(); await a?.requestExactAlarmsPermission();
  final p=await SharedPreferences.getInstance(); final raw=p.getString('careflow_patient_photos');
  if(raw!=null){final data=jsonDecode(raw) as Map<String,dynamic>;data.forEach((k,v){photosByPatient[k]=(v as List).map((e)=>Map<String,String>.from(e)).toList();});}
  if(mounted)setState(()=>initialized=true);
 }
 Future<void> savePatientPhotos() async {final p=await SharedPreferences.getInstance();await p.setString('careflow_patient_photos',jsonEncode(photosByPatient));}
 @override Widget build(BuildContext context) {
  final pages=[dashboard(),patientsPage(),listPage('الردهات والأقسام',wards,Icons.local_hospital_outlined,'إضافة ردهة'),settingsPage()];
  return Directionality(textDirection:TextDirection.rtl,child:Scaffold(
   appBar:AppBar(title:const Row(children:[Icon(Icons.health_and_safety,color:Color(0xff087e8b)),SizedBox(width:9),Text('رِعاية',style:TextStyle(fontWeight:FontWeight.bold)),SizedBox(width:8),Text('CareFlow',style:TextStyle(fontSize:13))]),actions:[IconButton(onPressed:widget.onTheme,icon:const Icon(Icons.brightness_6_outlined))]),
   body:!initialized?const Center(child:CircularProgressIndicator()):SafeArea(child:pages[tab]),
   bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const[
    NavigationDestination(icon:Icon(Icons.dashboard_outlined),label:'الرئيسية'),
    NavigationDestination(icon:Icon(Icons.people_outline),label:'المرضى'),
    NavigationDestination(icon:Icon(Icons.apartment_outlined),label:'الردهات'),
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
   statCard('العلاجات المسجلة',treatmentsByPatient.values.fold<int>(0,(sum,list)=>sum+list.length).toString(),Icons.medication_outlined),statCard('تنبيهات اليوم','2',Icons.notifications_active_outlined)]),
  const SizedBox(height:18),const Text('آخر المرضى',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
  ...patients.map((p)=>Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.person_outline)),title:Text(p),subtitle:const Text('ملف تجريبي'))))]);
 Widget patientsPage()=>ListView(padding:const EdgeInsets.all(16),children:[
  Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
   const Text('المرضى',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
   FilledButton.icon(onPressed:()=>addItem('المرضى',patients),icon:const Icon(Icons.add),label:const Text('إضافة مريض'))]),
  const SizedBox(height:12),
  ...patients.map((patient)=>Card(
   child:ExpansionTile(
    leading:const CircleAvatar(child:Icon(Icons.person_outline)),
    title:Text(patient),
    subtitle:Text('${(treatmentsByPatient[patient]??[]).length} علاج مسجل'),
    children:[
     if((treatmentsByPatient[patient]??[]).isEmpty)
      const Padding(padding:EdgeInsets.all(12),child:Text('لا توجد علاجات مضافة لهذا المريض')),
     ...(treatmentsByPatient[patient]??[]).map((t)=>ListTile(
      leading:const Icon(Icons.medication_outlined,color:Color(0xff087e8b)),
      title:Text(t),dense:true)),
     Padding(padding:const EdgeInsets.fromLTRB(16,4,16,4),child:Wrap(
      spacing:8,runSpacing:8,alignment:WrapAlignment.center,children:[
       OutlinedButton.icon(
        onPressed:()=>addTreatment(patient),
        icon:const Icon(Icons.add),label:const Text('إضافة علاج')),
       FilledButton.tonalIcon(
        onPressed:()=>openPatientProfile(patient),
        icon:const Icon(Icons.folder_open_outlined),label:const Text('ملف المريض'))
      ]))
    ]))),
 ]);
 void openPatientProfile(String patient){
  showDialog(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh)=>AlertDialog(
   title:Text('ملف المريض\\n$patient',style:const TextStyle(fontSize:18)),
   content:SizedBox(width:420,child:SingleChildScrollView(child:Column(
    mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     profileSection(ctx,refresh,patient,'المعلومات الأساسية',Icons.person_outline,
      patientInfo.putIfAbsent(patient,()=>{}),['العمر','الجنس','التشخيص','الحساسية'],true),
     profileSection(ctx,refresh,patient,'العلامات الحيوية',Icons.monitor_heart_outlined,
      vitalSigns.putIfAbsent(patient,()=>[]),[],false),
     profileSection(ctx,refresh,patient,'الملاحظات التمريضية',Icons.note_alt_outlined,
      nursingNotes.putIfAbsent(patient,()=>[]),[],false),
     profileSection(ctx,refresh,patient,'الفحوصات والتحاليل',Icons.biotech_outlined,
      investigations.putIfAbsent(patient,()=>[]),[],false),
     patientPhotoAlbum(ctx,refresh,patient),
    ]))),
   actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إغلاق'))]
  )));
 }
 Widget profileSection(BuildContext dialogContext,StateSetter refresh,String patient,
  String title,IconData icon,dynamic data,List<String> fields,bool isInfo){
  final count=isInfo?(data as Map<String,String>).length:(data as List<String>).length;
  return Card(child:ExpansionTile(
   leading:Icon(icon,color:const Color(0xff087e8b)),title:Text(title),
   subtitle:Text(count==0?'لا توجد معلومات مضافة':'$count عنصر'),
   children:[
    if(isInfo)...(fields.map((field){
     final value=(data as Map<String,String>)[field];
     return ListTile(dense:true,title:Text(field),subtitle:Text(value==null||value.isEmpty?'غير محدد':value));
    })),
    if(!isInfo)...((data as List<String>).map((entry)=>ListTile(
     dense:true,leading:const Icon(Icons.circle,size:7),title:Text(entry)))),
    Padding(padding:const EdgeInsets.fromLTRB(12,0,12,12),child:Align(
     alignment:Alignment.centerRight,child:TextButton.icon(
      onPressed:()=>addProfileEntry(dialogContext,refresh,patient,title,data,fields,isInfo),
      icon:const Icon(Icons.add),label:Text(isInfo?'إضافة معلومات':'إضافة سجل'))))
   ]));
 }
 void addProfileEntry(BuildContext dialogContext,StateSetter refresh,String patient,
  String section,dynamic data,List<String> fields,bool isInfo){
  final controllers=<String,TextEditingController>{};
  if(isInfo){for(final field in fields){controllers[field]=TextEditingController(text:(data as Map<String,String>)[field]??'');}}
  else {controllers['entry']=TextEditingController();}
  showDialog(context:dialogContext,builder:(entryContext)=>AlertDialog(
   title:Text('إضافة — $section'),
   content:SizedBox(width:380,child:SingleChildScrollView(child:Column(
    mainAxisSize:MainAxisSize.min,children:isInfo
     ?fields.map((field)=>Padding(padding:const EdgeInsets.only(bottom:8),child:TextField(
       controller:controllers[field],decoration:InputDecoration(labelText:field,border:const OutlineInputBorder())))).toList()
     :[TextField(controller:controllers['entry'],maxLines:3,decoration:const InputDecoration(
       hintText:'اكتب التفاصيل',border:OutlineInputBorder()))]))),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(entryContext),child:const Text('إلغاء')),
    FilledButton(onPressed:(){
     if(isInfo){
      final map=data as Map<String,String>;
      for(final field in fields){final value=controllers[field]!.text.trim();if(value.isNotEmpty)map[field]=value;}
     }else{
      final value=controllers['entry']!.text.trim();
      if(value.isNotEmpty)(data as List<String>).insert(0,value);
     }
     setState((){});
     refresh((){});
     Navigator.pop(entryContext);
    },child:const Text('حفظ'))
   ]));
 }

 Widget patientPhotoAlbum(BuildContext ctx,StateSetter refresh,String patient){
  final list=photosByPatient.putIfAbsent(patient,()=>[]);
  return Card(child:ExpansionTile(leading:const Icon(Icons.photo_library_outlined),title:const Text('ألبوم صور التحاليل والفحوصات'),subtitle:Text(list.length.toString()+' صورة'),children:[
   Wrap(spacing:8,children:[OutlinedButton.icon(onPressed:()=>takePatientPhoto(ctx,refresh,patient),icon:const Icon(Icons.camera_alt),label:const Text('التقاط صورة')),FilledButton.tonalIcon(onPressed:()=>pickPatientPhotos(ctx,refresh,patient),icon:const Icon(Icons.photo_library),label:const Text('اختيار من المعرض'))]),
   if(list.isEmpty)const Padding(padding:EdgeInsets.all(12),child:Text('لا توجد صور مضافة')),
   Padding(padding:const EdgeInsets.all(8),child:GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:3,crossAxisSpacing:8,mainAxisSpacing:8),itemCount:list.length,itemBuilder:(c,i)=>GestureDetector(onTap:()=>viewPatientPhoto(ctx,refresh,patient,i),child:ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.file(File(list[i]['path']!),fit:BoxFit.cover)))))
  ]));
 }
 Future<void> takePatientPhoto(BuildContext ctx,StateSetter refresh,String patient) async {final x=await picker.pickImage(source:ImageSource.camera,imageQuality:100);if(x!=null)await storePatientPhoto(refresh,patient,x);}
 Future<void> pickPatientPhotos(BuildContext ctx,StateSetter refresh,String patient) async {final xs=await picker.pickMultiImage(imageQuality:100);for(final x in xs){await storePatientPhoto(refresh,patient,x);}}
 Future<void> storePatientPhoto(StateSetter refresh,String patient,XFile x) async {
  final dir=await getApplicationDocumentsDirectory();final folder=Directory(dir.path+'/patient_lab_photos');if(!await folder.exists())await folder.create(recursive:true);
  final path=folder.path+'/'+DateTime.now().microsecondsSinceEpoch.toString()+'_'+x.name;await File(x.path).copy(path);
  photosByPatient.putIfAbsent(patient,()=>[]).insert(0,{'path':path,'date':DateTime.now().toIso8601String()});await savePatientPhotos();if(mounted)refresh((){});
 }
 void viewPatientPhoto(BuildContext ctx,StateSetter refresh,String patient,int index){showDialog(context:ctx,builder:(d)=>Dialog(child:Column(mainAxisSize:MainAxisSize.min,children:[
  Padding(padding:const EdgeInsets.all(8),child:Row(children:[Expanded(child:Text(photosByPatient[patient]![index]['date']??'')),IconButton(icon:const Icon(Icons.delete_outline,color:Colors.red),onPressed:()async{final item=photosByPatient[patient]!.removeAt(index);try{await File(item['path']!).delete();}catch(_){}await savePatientPhotos();if(d.mounted)Navigator.pop(d);refresh((){});})])),
  Flexible(child:InteractiveViewer(minScale:0.5,maxScale:5,child:Image.file(File(photosByPatient[patient]![index]['path']!),fit:BoxFit.contain)))
 ])));}

 void addTreatment(String patient){
  final controller=TextEditingController();
  showDialog(context:context,builder:(ctx)=>AlertDialog(
   title:Text('إضافة علاج — $patient'),
   content:TextField(controller:controller,maxLines:3,autofocus:true,
    decoration:const InputDecoration(hintText:'اسم العلاج، الجرعة، الطريق، الوقت',border:OutlineInputBorder())),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),
    FilledButton(onPressed:(){
     final value=controller.text.trim();
     if(value.isNotEmpty)setState(()=>treatmentsByPatient.putIfAbsent(patient,()=>[]).add(value));
     Navigator.pop(ctx);
    },child:const Text('حفظ العلاج'))
   ]));
 }
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
