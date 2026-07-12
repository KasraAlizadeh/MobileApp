import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class JourneyStorageService {
  static Future<String> upload(String fileName, File file, String userId, String journeyId, String subFolder) async {
    Reference ref = FirebaseStorage.instance
        .ref()
        .child('media/$userId/$journeyId/$subFolder/$fileName');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  static Future<List<String>> moveStorageFolder(String oldFolderName, String newFolderName, List<String> currentUrls) async {
    List<String> updatedUrls = List.from(currentUrls);
    List<String> fileNames = ["visa.pdf", "ticket.pdf", "insurance.pdf"];

    for (int i = 0; i < currentUrls.length; i++) {
      if (currentUrls[i].isEmpty) continue;
      try {
        Reference oldRef = FirebaseStorage.instance.ref().child('pdfs/$oldFolderName/${fileNames[i]}');
        Reference newRef = FirebaseStorage.instance.ref().child('pdfs/$newFolderName/${fileNames[i]}');

        final data = await oldRef.getData();
        if (data != null) {
          await newRef.putData(data);
          updatedUrls[i] = await newRef.getDownloadURL();
          await oldRef.delete();
        }
      } catch (e) {
        print("Failed moving file index \$i: \$e");
      }
    }
    return updatedUrls;
  }
}