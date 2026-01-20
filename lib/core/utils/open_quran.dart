
  import 'package:url_launcher/url_launcher.dart';

Future<void> openQuranLink(int surah, int ayah) async {
    final String appUrl = "quran://$surah/$ayah";
    final String webUrl = "https://quran.com/$surah/$ayah";

    final Uri appUri = Uri.parse(appUrl);
    final Uri webUri = Uri.parse(webUrl);

    try {
      bool launched = await launchUrl(
        appUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }
