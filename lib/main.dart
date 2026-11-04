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
  debugShowCheckedModeBanner:false, title:'عناية | ENAYA', themeMode:mode,
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
 final completedTreatments=<String>{};
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
  final p=await SharedPreferences.getInstance();
  final savedDoses=p.getString('careflow_treatments');if(savedDoses!=null){final m=jsonDecode(savedDoses) as Map<String,dynamic>;m.forEach((k,v){treatmentsByPatient[k]=(v as List).cast<String>();});}
  final done=p.getStringList('careflow_completed_treatments');if(done!=null)completedTreatments.addAll(done);
  final rawPatients=p.getStringList('enaya_patients');if(rawPatients!=null){patients..clear()..addAll(rawPatients);}
  final rawWards=p.getStringList('enaya_wards');if(rawWards!=null){wards..clear()..addAll(rawWards);}
  Map<String,dynamic> readSaved(String key){final value=p.getString(key);return value==null?{}:Map<String,dynamic>.from(jsonDecode(value));}
  patientInfo.addAll(readSaved('enaya_patient_info').map((k,v)=>MapEntry(k,Map<String,String>.from(v))));
  vitalSigns.addAll(readSaved('enaya_vitals').map((k,v)=>MapEntry(k,List<String>.from(v))));
  nursingNotes.addAll(readSaved('enaya_notes').map((k,v)=>MapEntry(k,List<String>.from(v))));
  investigations.addAll(readSaved('enaya_investigations').map((k,v)=>MapEntry(k,List<String>.from(v))));
  final raw=p.getString('careflow_patient_photos');
  if(raw!=null){final data=jsonDecode(raw) as Map<String,dynamic>;data.forEach((k,v){photosByPatient[k]=(v as List).map((e)=>Map<String,String>.from(e)).toList();});}
  await rescheduleAllTreatmentNotifications();
  if(mounted)setState(()=>initialized=true);
 }
 int treatmentNotificationBase(String raw){var hash=0x811c9dc5;for(final unit in raw.codeUnits){hash^=unit;hash=(hash*0x01000193)&0x3fffffff;}return 10000+(hash%1000000000);}
 Future<void> cancelTreatmentNotifications(String raw) async {final base=treatmentNotificationBase(raw);for(var i=0;i<=31;i++){await notices.cancel(base+i);}}
 Future<void> rescheduleAllTreatmentNotifications() async {await notices.cancelAll();for(final entry in treatmentsByPatient.entries){for(final raw in entry.value){if(!completedTreatments.contains(raw))await scheduleTreatment(entry.key,raw);}}}
 Future<void> saveAllData() async {
  final p=await SharedPreferences.getInstance();
  await p.setStringList('enaya_patients',patients);
  await p.setStringList('enaya_wards',wards);
  await p.setString('enaya_patient_info',jsonEncode(patientInfo));
  await p.setString('enaya_vitals',jsonEncode(vitalSigns));
  await p.setString('enaya_notes',jsonEncode(nursingNotes));
  await p.setString('enaya_investigations',jsonEncode(investigations));
 }
 Future<void> savePatientPhotos() async {final p=await SharedPreferences.getInstance();await p.setString('careflow_patient_photos',jsonEncode(photosByPatient));}
 Future<void> saveTreatments() async {final p=await SharedPreferences.getInstance();await p.setString('careflow_treatments',jsonEncode(treatmentsByPatient));await p.setStringList('careflow_completed_treatments',completedTreatments.toList());}
 @override Widget build(BuildContext context) {
  final pages=[dashboard(),patientsPage(),listPage('الردهات والأقسام',wards,Icons.local_hospital_outlined,'إضافة ردهة'),treatmentsOverviewPage(),settingsPage()];
  return Directionality(textDirection:TextDirection.rtl,child:Scaffold(
   appBar:AppBar(title:const Row(children:[Icon(Icons.health_and_safety,color:Color(0xff087e8b)),SizedBox(width:9),Text('عناية',style:TextStyle(fontWeight:FontWeight.bold)),SizedBox(width:8),Text('ENAYA',style:TextStyle(fontSize:13))]),actions:[IconButton(onPressed:widget.onTheme,icon:const Icon(Icons.brightness_6_outlined))]),
   body:!initialized?const Center(child:CircularProgressIndicator()):SafeArea(child:pages[tab]),
   bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const[
    NavigationDestination(icon:Icon(Icons.dashboard_outlined),label:'الرئيسية'),
    NavigationDestination(icon:Icon(Icons.people_outline),label:'المرضى'),
    NavigationDestination(icon:Icon(Icons.apartment_outlined),label:'الردهات'),
    NavigationDestination(icon:Icon(Icons.medication_outlined),label:'جدول العلاجات'),
    NavigationDestination(icon:Icon(Icons.settings_outlined),label:'الإعدادات')])));
 }
 Widget dashboard()=>ListView(padding:const EdgeInsets.all(16),children:[
  Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(borderRadius:BorderRadius.circular(22),gradient:const LinearGradient(colors:[Color(0xff087e8b),Color(0xff155e75)])),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Text('مرحباً بك في عناية',style:TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.bold)),SizedBox(height:8),
   Text('نظام تجريبي لتنظيم العمل داخل المؤسسة الصحية',style:TextStyle(color:Colors.white70)),SizedBox(height:16),
   Row(children:[Icon(Icons.shield_outlined,color:Colors.white),SizedBox(width:8),Text('بيئة تجريبية — بيانات وهمية',style:TextStyle(color:Colors.white))])])),
  const SizedBox(height:18),
  GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:2,crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:1.45,children:[
   statCard('المرضى',patients.length.toString(),Icons.people_alt_outlined,onTap:()=>setState(()=>tab=1)),statCard('الردهات',wards.length.toString(),Icons.apartment,onTap:()=>setState(()=>tab=2)),
   statCard('العلاجات المسجلة',treatmentsByPatient.values.fold<int>(0,(sum,list)=>sum+list.length).toString(),Icons.medication_outlined,onTap:()=>setState(()=>tab=3)),statCard('التنبيهات',treatmentsByPatient.values.fold<int>(0,(sum,list)=>sum+list.length).toString(),Icons.notifications_active_outlined,onTap:()=>setState(()=>tab=3))]),
  const SizedBox(height:18),const Text('آخر المرضى',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
  ...patients.map((p)=>Card(child:ListTile(onTap:()=>openPatientProfile(p),leading:const CircleAvatar(child:Icon(Icons.person_outline)),title:Text(p),subtitle:const Text('اضغط لفتح ملف المريض'),trailing:const Icon(Icons.chevron_left))))]);
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
      title:Text(t.split('|').first),
      subtitle:t.split('|').length==4?Text('الجرعة: '+t.split('|')[1]+' • '+t.split('|')[2]+' • '+DateTime.parse(t.split('|')[3]).toLocal().toString()+' • '+(completedTreatments.contains(t)?'تم التأكيد':'بانتظار التأكيد')):null,
      trailing:Wrap(spacing:0,children:[if(t.split('|').length==4&&!completedTreatments.contains(t))TextButton(onPressed:()=>confirmTreatment(t),child:const Text('تم إعطاء العلاج')),IconButton(tooltip:'حذف العلاج',onPressed:()=>confirmDeleteTreatment(patient,t),icon:const Icon(Icons.delete_outline,color:Colors.red))]),dense:true)),
     Padding(padding:const EdgeInsets.fromLTRB(16,4,16,4),child:Wrap(
      spacing:8,runSpacing:8,alignment:WrapAlignment.center,children:[
       OutlinedButton.icon(
        onPressed:()=>addTreatment(patient),
        icon:const Icon(Icons.add),label:const Text('إضافة علاج')),
       FilledButton.tonalIcon(
        onPressed:()=>openPatientProfile(patient),
        icon:const Icon(Icons.folder_open_outlined),label:const Text('ملف المريض')),
       OutlinedButton.icon(onPressed:()=>confirmDeletePatient(patient),icon:const Icon(Icons.delete_outline,color:Colors.red),label:const Text('حذف المريض'))
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
     patientTreatmentsSection(ctx,refresh,patient),
     patientPhotoAlbum(ctx,refresh,patient),
    ]))),
   actions:[TextButton(onPressed:()=>changePatientWard(patient,ctx),child:const Text('نقل إلى ردهة')),TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إغلاق'))]
  )));
 }
 void changePatientWard(String patient,BuildContext profileContext){
  String selected=wards.firstWhere((w)=>patient.contains(w),orElse:()=>wards.isNotEmpty?wards.first:'');
  showDialog(context:profileContext,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh)=>AlertDialog(
   title:const Text('نقل المريض إلى ردهة أخرى'),
   content:DropdownButtonFormField<String>(value:wards.contains(selected)?selected:null,items:wards.map((w)=>DropdownMenuItem(value:w,child:Text(w))).toList(),onChanged:(v)=>refresh(()=>selected=v??'')),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),
    FilledButton(onPressed:()async{
     if(selected.isNotEmpty){
      final name=patient.split(' — ').first;
      final updated='$name — $selected';
      if(updated!=patient){
       final index=patients.indexOf(patient);if(index>=0)patients[index]=updated;
       if(patientInfo.containsKey(patient))patientInfo[updated]=patientInfo.remove(patient)!;
       if(vitalSigns.containsKey(patient))vitalSigns[updated]=vitalSigns.remove(patient)!;
       if(nursingNotes.containsKey(patient))nursingNotes[updated]=nursingNotes.remove(patient)!;
       if(investigations.containsKey(patient))investigations[updated]=investigations.remove(patient)!;
       if(photosByPatient.containsKey(patient))photosByPatient[updated]=photosByPatient.remove(patient)!;
       final doses=treatmentsByPatient.remove(patient)??<String>[];
       treatmentsByPatient[updated]=doses;
       for(final raw in doses){
        await cancelTreatmentNotifications(raw);
        if(!completedTreatments.contains(raw))await scheduleTreatment(updated,raw);
       }
       await saveAllData();await savePatientPhotos();await saveTreatments();
      }
     }
     if(ctx.mounted)Navigator.pop(ctx);
     if(profileContext.mounted)Navigator.pop(profileContext);
     if(mounted)setState((){});
    },child:const Text('تأكيد النقل'))
   ]
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
     saveAllData();
     refresh((){});
     Navigator.pop(entryContext);
    },child:const Text('حفظ'))
   ]));
 }

 Widget patientTreatmentsSection(BuildContext ctx,StateSetter refresh,String patient){
  final list=treatmentsByPatient.putIfAbsent(patient,()=>[]);
  return Card(child:ExpansionTile(
   initiallyExpanded:true,
   leading:const Icon(Icons.medication_outlined,color:Color(0xff087e8b)),
   title:const Text('العلاجات الخاصة بالمريض',style:TextStyle(fontWeight:FontWeight.bold)),
   subtitle:Text('${list.length} علاج مسجل'),
   children:[
    if(list.isEmpty)const Padding(padding:EdgeInsets.all(12),child:Text('لا توجد علاجات مضافة لهذا المريض')),
    ...list.map((raw)=>treatmentTile(patient,raw,compact:false)),
    Padding(padding:const EdgeInsets.all(12),child:Align(alignment:Alignment.centerRight,child:FilledButton.icon(
     onPressed:()=>addTreatment(patient),icon:const Icon(Icons.add),label:const Text('إضافة علاج'))))
   ]));
 }
 String treatmentTimeLabel(String raw){
  final parts=raw.split('|');if(parts.length!=4)return 'وقت غير محدد';
  final when=DateTime.tryParse(parts[3]);if(when==null)return 'وقت غير محدد';
  final hour=when.hour%12==0?12:when.hour%12;
  final minute=when.minute.toString().padLeft(2,'0');
  return '${hour.toString().padLeft(2,'0')}:$minute ${when.hour<12?'AM':'PM'}';
 }
 Widget treatmentTile(String patient,String raw,{bool compact=true}){
  final parts=raw.split('|');
  final name=parts.isNotEmpty?parts[0]:'علاج';
  final dose=parts.length>1?parts[1]:'—';
  final route=parts.length>2?parts[2]:'—';
  final isDone=completedTreatments.contains(raw);
  return Card(margin:const EdgeInsets.symmetric(horizontal:10,vertical:5),child:Padding(
   padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Text(name,style:TextStyle(fontSize:compact?16:18,fontWeight:FontWeight.bold)),
    const SizedBox(height:6),
    Wrap(spacing:14,runSpacing:8,children:[
     Text('الجرعة: $dose',style:const TextStyle(fontSize:15)),
     Text('طريقة الإعطاء: $route',style:const TextStyle(fontSize:15))
    ]),
    const SizedBox(height:8),
    Row(children:[
     const Icon(Icons.access_time,color:Color(0xff087e8b),size:22),
     const SizedBox(width:7),
     Text(treatmentTimeLabel(raw),style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold,letterSpacing:0.4)),
     const Spacer(),
     Text(isDone?'تم إعطاء العلاج':'بانتظار التأكيد',style:TextStyle(fontSize:12,color:isDone?Colors.green:Colors.orange,fontWeight:FontWeight.bold))
    ]),
    if(parts.length==4&&DateTime.tryParse(parts[3])!=null)
     Text('التاريخ: ${DateTime.parse(parts[3]).toLocal().toString().substring(0,10)}',style:const TextStyle(fontSize:13,color:Colors.grey)),
    Wrap(alignment:WrapAlignment.spaceBetween,children:[if(!isDone)TextButton.icon(onPressed:()=>confirmTreatment(raw),icon:const Icon(Icons.check_circle_outline),label:const Text('تم إعطاء العلاج')),TextButton.icon(onPressed:()=>confirmDeleteTreatment(patient,raw),icon:const Icon(Icons.delete_outline,color:Colors.red),label:const Text('حذف العلاج'))])
   ])));
 }
 Widget treatmentsOverviewPage()=>ListView(padding:const EdgeInsets.all(16),children:[
  const Text('جدول العلاجات',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
  const SizedBox(height:6),
  const Text('جميع المرضى وعلاجاتهم والجرعات ومواعيد الإعطاء بنظام 12 ساعة'),
  const SizedBox(height:12),
  if(treatmentsByPatient.values.every((items)=>items.isEmpty))
   const Card(child:Padding(padding:EdgeInsets.all(20),child:Text('لا توجد علاجات مسجلة حالياً'))),
  ...patients.map((patient){
   final list=treatmentsByPatient[patient]??<String>[];
   return Card(child:ExpansionTile(
    initiallyExpanded:true,
    leading:const CircleAvatar(child:Icon(Icons.person_outline)),
    title:Text(patient,style:const TextStyle(fontWeight:FontWeight.bold)),
    subtitle:Text('${list.length} علاج'),
    children:list.isEmpty
     ?[const Padding(padding:EdgeInsets.all(12),child:Text('لا توجد علاجات لهذا المريض'))]
     :list.map((raw)=>treatmentTile(patient,raw,compact:false)).toList()
   ));
  })
 ]);
 Widget patientPhotoAlbum(BuildContext ctx,StateSetter refresh,String patient){
  final list=photosByPatient.putIfAbsent(patient,()=>[]);
  return Card(child:ExpansionTile(leading:const Icon(Icons.photo_library_outlined),title:const Text('ألبوم صور التحاليل والفحوصات'),subtitle:Text(list.length.toString()+' صورة'),children:[
   Wrap(spacing:8,children:[OutlinedButton.icon(onPressed:()=>takePatientPhoto(ctx,refresh,patient),icon:const Icon(Icons.camera_alt),label:const Text('التقاط صورة')),FilledButton.tonalIcon(onPressed:()=>pickPatientPhotos(ctx,refresh,patient),icon:const Icon(Icons.photo_library),label:const Text('اختيار من المعرض'))]),
   if(list.isEmpty)const Padding(padding:EdgeInsets.all(12),child:Text('لا توجد صور مضافة')),
   Padding(padding:const EdgeInsets.all(8),child:GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:3,crossAxisSpacing:8,mainAxisSpacing:8),itemCount:list.length,itemBuilder:(c,i)=>GestureDetector(onTap:()=>viewPatientPhoto(ctx,refresh,patient,i),child:ClipRRect(borderRadius:BorderRadius.circular(8),child:Image.file(File(list[i]['path']!),fit:BoxFit.cover)))))
  ]));
 }
 Future<void> takePatientPhoto(BuildContext ctx,StateSetter refresh,String patient) async {final x=await picker.pickImage(source:ImageSource.camera);if(x!=null)await storePatientPhoto(refresh,patient,x);}
 Future<void> pickPatientPhotos(BuildContext ctx,StateSetter refresh,String patient) async {final xs=await picker.pickMultiImage();for(final x in xs){await storePatientPhoto(refresh,patient,x);}}
 Future<void> storePatientPhoto(StateSetter refresh,String patient,XFile x) async {
  final dir=await getApplicationDocumentsDirectory();final folder=Directory(dir.path+'/patient_lab_photos');if(!await folder.exists())await folder.create(recursive:true);
  final path=folder.path+'/'+DateTime.now().microsecondsSinceEpoch.toString()+'_'+x.name;await File(x.path).copy(path);
  photosByPatient.putIfAbsent(patient,()=>[]).insert(0,{'path':path,'date':DateTime.now().toIso8601String()});await savePatientPhotos();if(mounted)refresh((){});
 }
 void viewPatientPhoto(BuildContext ctx,StateSetter refresh,String patient,int index){showDialog(context:ctx,builder:(d)=>Dialog(child:Column(mainAxisSize:MainAxisSize.min,children:[
  Padding(padding:const EdgeInsets.all(8),child:Row(children:[Expanded(child:Text(photosByPatient[patient]![index]['date']??'')),IconButton(icon:const Icon(Icons.delete_outline,color:Colors.red),onPressed:()async{final item=photosByPatient[patient]!.removeAt(index);try{await File(item['path']!).delete();}catch(_){}await savePatientPhotos();if(d.mounted)Navigator.pop(d);refresh((){});})])),
  Flexible(child:InteractiveViewer(minScale:0.5,maxScale:5,child:Image.file(File(photosByPatient[patient]![index]['path']!),fit:BoxFit.contain)))
 ])));}


 Future<void> scheduleNotification(int id,String title,String body,DateTime when,NotificationDetails details,String raw) async {try{await notices.zonedSchedule(id,title,body,tz.TZDateTime.from(when,tz.local),details,androidScheduleMode:AndroidScheduleMode.exactAllowWhileIdle,payload:raw);}catch(_){try{await notices.zonedSchedule(id,title,body,tz.TZDateTime.from(when,tz.local),details,androidScheduleMode:AndroidScheduleMode.inexactAllowWhileIdle,payload:raw);}catch(__){}}}
 Future<void> scheduleTreatment(String patient,String raw) async {
  final p=raw.split('|');if(p.length!=4)return;final when=DateTime.tryParse(p[3]);if(when==null)return;
  final base=treatmentNotificationBase(raw),now=DateTime.now();
  const pre=NotificationDetails(android:AndroidNotificationDetails('careflow_pre','تنبيه قبل موعد العلاج',channelDescription:'تنبيه قبل الموعد بخمس دقائق',importance:Importance.high,priority:Priority.high,playSound:true));
  const due=NotificationDetails(android:AndroidNotificationDetails('careflow_due','مواعيد إعطاء العلاج',channelDescription:'تنبيهات صوتية متكررة لموعد العلاج',importance:Importance.max,priority:Priority.max,playSound:true,category:AndroidNotificationCategory.alarm));
  final before=when.subtract(const Duration(minutes:5));
  if(before.isAfter(now))await scheduleNotification(base,'موعد علاج قريب','بعد 5 دقائق: '+patient+' — '+p[0]+'، '+p[1]+'، '+p[2],before,pre,raw);
  if(when.isAfter(now))await scheduleNotification(base+1,'حان موعد إعطاء العلاج',patient+' — '+p[0]+'، الجرعة '+p[1]+'، طريقة الإعطاء '+p[2],when,due,raw);
  for(var i=1;i<=30;i++){final at=when.add(Duration(minutes:2*i));if(at.isAfter(now))await scheduleNotification(base+1+i,'تذكير: العلاج لم يُؤكّد بعد',patient+' — '+p[0]+'، '+p[1]+'، '+p[2]+'. افتح عناية وسجّل إعطاء العلاج.',at,due,raw);}
 }
 Future<void> confirmTreatment(String raw) async {await cancelTreatmentNotifications(raw);completedTreatments.add(raw);await saveTreatments();if(mounted)setState((){});}

 Future<void> confirmDeleteTreatment(String patient,String raw) async {final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('حذف العلاج'),content:const Text('هل تريد حذف هذا العلاج وإلغاء جميع تنبيهاته؟'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),style:FilledButton.styleFrom(backgroundColor:Colors.red),child:const Text('حذف'))]));if(ok!=true)return;await cancelTreatmentNotifications(raw);treatmentsByPatient[patient]?.remove(raw);completedTreatments.remove(raw);await saveTreatments();if(mounted)setState((){});}
 Future<void> confirmDeletePatient(String patient) async {final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('حذف المريض'),content:Text('هل تريد حذف ملف المريض "$patient" مع علاجاته وصوره وسجلاته؟ لا يمكن التراجع عن هذا الإجراء.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),style:FilledButton.styleFrom(backgroundColor:Colors.red),child:const Text('حذف نهائياً'))]));if(ok!=true)return;final doses=treatmentsByPatient.remove(patient)??<String>[];for(final raw in doses){await cancelTreatmentNotifications(raw);completedTreatments.remove(raw);}patients.remove(patient);patientInfo.remove(patient);vitalSigns.remove(patient);nursingNotes.remove(patient);investigations.remove(patient);photosByPatient.remove(patient);await saveAllData();await savePatientPhotos();await saveTreatments();if(mounted)setState((){});}
 void addTreatment(String patient) async {
  final name=TextEditingController(),dose=TextEditingController();
  String route='IV';DateTime day=DateTime.now();TimeOfDay time=TimeOfDay.fromDateTime(DateTime.now().add(const Duration(minutes:10)));
  final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh)=>AlertDialog(
   title:Text('إضافة علاج — '+patient),
   content:SizedBox(width:380,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    TextField(controller:name,decoration:const InputDecoration(labelText:'اسم العلاج')),
    TextField(controller:dose,decoration:const InputDecoration(labelText:'الجرعة')),
    DropdownButtonFormField<String>(value:route,decoration:const InputDecoration(labelText:'كيفية الإعطاء'),items:const ['IV','IM','Oral','SC','Topical','Inhalation','Other'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v)=>refresh(()=>route=v??'IV')),
    ListTile(title:const Text('تاريخ العلاج'),subtitle:Text(day.toString().substring(0,10)),onTap:()async{final d=await showDatePicker(context:ctx,initialDate:day,firstDate:DateTime.now().subtract(const Duration(days:1)),lastDate:DateTime.now().add(const Duration(days:365)));if(d!=null)refresh(()=>day=d);}),
    ListTile(title:const Text('وقت إعطاء العلاج'),subtitle:Text(time.format(ctx)),onTap:()async{final t=await showTimePicker(context:ctx,initialTime:time);if(t!=null)refresh(()=>time=t);})
   ]))),
   actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حفظ العلاج'))]
  )));
  if(ok==true&&name.text.trim().isNotEmpty&&dose.text.trim().isNotEmpty){
   final when=DateTime(day.year,day.month,day.day,time.hour,time.minute);
   final raw=name.text.trim()+'|'+dose.text.trim()+'|'+route+'|'+when.toIso8601String();
   setState(()=>treatmentsByPatient.putIfAbsent(patient,()=>[]).add(raw));
   await saveTreatments();await scheduleTreatment(patient,raw);
  }
 }
 Widget statCard(String title,String value,IconData icon,{VoidCallback? onTap})=>Card(elevation:0,color:Theme.of(context).colorScheme.surfaceContainerHighest,child:InkWell(borderRadius:BorderRadius.circular(12),onTap:onTap,child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Icon(icon,color:const Color(0xff087e8b)),Text(value,style:const TextStyle(fontSize:25,fontWeight:FontWeight.bold)),Text(title,style:const TextStyle(fontSize:13))]))));
 Widget listPage(String title,List<String> items,IconData icon,String action)=>ListView(padding:const EdgeInsets.all(16),children:[
  Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(title,style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),FilledButton.icon(onPressed:()=>addItem(title,items),icon:const Icon(Icons.add),label:Text(action))]),
  const SizedBox(height:12),...items.map((item)=>Card(child:ListTile(onTap:title.contains('الردهات')?()=>showWardDetails(item):null,leading:CircleAvatar(child:Icon(icon)),title:Text(item),subtitle:Text(title.contains('الردهات')?'اضغط لعرض مرضى الردهة':'بيانات للعرض فقط'),trailing:const Icon(Icons.chevron_left))))]);
 void showAbout(){
  showDialog(context:context,builder:(ctx)=>AlertDialog(
   title:const Text('حول تطبيق عناية'),
   content:const SizedBox(width:380,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    CircleAvatar(radius:38,child:Icon(Icons.health_and_safety_outlined,size:42)),
    SizedBox(height:12),
    Text('عناية | ENAYA',style:TextStyle(fontSize:21,fontWeight:FontWeight.bold)),
    Text('نظام إدارة المستشفيات والرعاية التمريضية',textAlign:TextAlign.center),
    Divider(height:24),
    ListTile(contentPadding:EdgeInsets.zero,title:Text('المطوّر'),subtitle:Text('الممرض تمار ميثم كمال الدين الحسيني'),leading:Icon(Icons.person_outline)),
    ListTile(contentPadding:EdgeInsets.zero,title:Text('الإصدار'),subtitle:Text('0.3.1 • نسخة تجريبية'),leading:Icon(Icons.info_outline)),
    ListTile(contentPadding:EdgeInsets.zero,title:Text('الهدف'),subtitle:Text('تنظيم المرضى والردهات والعلاجات والملفات، وتسهيل العمل التمريضي داخل المؤسسات الصحية.'),leading:Icon(Icons.flag_outlined)),
    Text('مساحة صورة المطوّر — تضاف لاحقاً',style:TextStyle(fontSize:12,color:Colors.grey))
   ]))),
   actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إغلاق'))]
  ));
 }
 void showTreatmentsOverview(){
  final entries=<String>[];
  treatmentsByPatient.forEach((patient,list){for(final t in list){entries.add('$patient — ${t.split('|').first}');}});
  showDialog(context:context,builder:(ctx)=>AlertDialog(
   title:const Text('العلاجات والتنبيهات'),
   content:SizedBox(width:380,child:entries.isEmpty?const Text('لا توجد علاجات مسجلة'):ListView(shrinkWrap:true,children:entries.map((e)=>ListTile(leading:const Icon(Icons.notifications_active_outlined),title:Text(e))).toList())),
   actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إغلاق'))]
  ));
 }
 void showWardDetails(String ward){
  final list=patients.where((p)=>p.contains(ward)).toList();
  showDialog(context:context,builder:(ctx)=>AlertDialog(
   title:Text(ward),
   content:SizedBox(width:380,child:list.isEmpty?const Text('لا يوجد مرضى مسجلون لهذه الردهة حالياً'):ListView(shrinkWrap:true,children:list.map((p)=>ListTile(onTap:(){Navigator.pop(ctx);openPatientProfile(p);},leading:const CircleAvatar(child:Icon(Icons.person_outline)),title:Text(p),subtitle:const Text('فتح ملف المريض'))).toList())),
   actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إغلاق'))]
  ));
 }
 void addItem(String title,List<String> items){
  final controller=TextEditingController();
  String selectedWard=wards.isNotEmpty?wards.first:'';
  showDialog(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh)=>AlertDialog(
   title:Text('إضافة إلى $title'),
   content:Column(mainAxisSize:MainAxisSize.min,children:[
    TextField(controller:controller,autofocus:true,decoration:const InputDecoration(hintText:'اكتب الاسم أو التفاصيل')),
    if(title.contains('المرضى')) ...[
     const SizedBox(height:12),
     DropdownButtonFormField<String>(value:wards.contains(selectedWard)?selectedWard:null,decoration:const InputDecoration(labelText:'الردهة'),items:wards.map((w)=>DropdownMenuItem(value:w,child:Text(w))).toList(),onChanged:(v)=>refresh(()=>selectedWard=v??''))
    ]
   ]),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),
    FilledButton(onPressed:(){
     final name=controller.text.trim();
     if(name.isNotEmpty){
      final entry=title.contains('المرضى')&&selectedWard.isNotEmpty?'$name — $selectedWard':name;
      setState(()=>items.add(entry));saveAllData();
     }
     Navigator.pop(ctx);
    },child:const Text('إضافة'))
   ]
  )));
 }
 Widget settingsPage()=>ListView(padding:const EdgeInsets.all(16),children:[
  const Text('الإعدادات',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),const SizedBox(height:12),
  const Card(child:ListTile(leading:Icon(Icons.business_outlined),title:Text('المؤسسة الصحية'),subtitle:Text('مؤسسة تجريبية'))),
  const Card(child:ListTile(leading:Icon(Icons.admin_panel_settings_outlined),title:Text('إدارة الصلاحيات'),subtitle:Text('ستتوفر عند ربط الخادم'))),
  const Card(child:ListTile(leading:Icon(Icons.cloud_outlined),title:Text('قاعدة البيانات'),subtitle:Text('غير متصلة — البيانات محلية مؤقتة'))),
  Card(child:ListTile(onTap:showAbout,leading:const Icon(Icons.info_outline),title:const Text('حول التطبيق'),subtitle:const Text('عناية ENAYA • الإصدار 0.3.1'))),
  const Padding(padding:EdgeInsets.all(12),child:Text('تنبيه: هذه نسخة واجهة تجريبية فقط. لا تستخدمها لتسجيل بيانات مرضى حقيقية أو لاتخاذ قرارات علاجية.',style:TextStyle(color:Colors.orange)))]);
}
