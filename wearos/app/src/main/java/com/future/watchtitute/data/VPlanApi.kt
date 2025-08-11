package com.future.watchtitute.data

import android.util.Xml
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.xmlpull.v1.XmlPullParser
import java.io.StringReader
import java.net.HttpURLConnection
import java.net.URL

class VPlanApi {

    private var xmlString: String? = null

    suspend fun getClasses(schoolNumber: String, auth: String): List<String> {
        return withContext(Dispatchers.IO) {
            val url = URL("https://www.stundenplan24.de/$schoolNumber/mobil/mobdaten/Klassen.xml")
            val connection = url.openConnection() as HttpURLConnection
            connection.setRequestProperty("Authorization", "Basic $auth")
            val inputStream = connection.inputStream
            var xml = inputStream.bufferedReader().use { it.readText() }
            if (xml.startsWith("\uFEFF")) {
                xml = xml.substring(1)
            }
            xmlString = xml
            parseClasses(xmlString!!)
        }
    }

    suspend fun getVPlan(className: String): List<VPlanEntry> {
        return withContext(Dispatchers.IO) {
            parseVPlanXml(xmlString!!, className)
        }
    }

    private fun parseClasses(xmlString: String): List<String> {
        val parser: XmlPullParser = Xml.newPullParser()
        parser.setFeature(XmlPullParser.FEATURE_PROCESS_NAMESPACES, false)
        parser.setInput(StringReader(xmlString))

        val classes = mutableListOf<String>()
        var eventType = parser.eventType
        while (eventType != XmlPullParser.END_DOCUMENT) {
            if (eventType == XmlPullParser.START_TAG && parser.name.equals("Kurz", ignoreCase = true)) {
                parser.next()
                if (parser.eventType == XmlPullParser.TEXT) {
                    classes.add(parser.text)
                }
            }
            eventType = parser.next()
        }
        return classes.distinct()
    }

    private fun parseVPlanXml(xmlString: String, className: String): List<VPlanEntry> {
        val parser: XmlPullParser = Xml.newPullParser()
        parser.setFeature(XmlPullParser.FEATURE_PROCESS_NAMESPACES, false)
        parser.setInput(StringReader(xmlString))

        val entries = mutableListOf<VPlanEntry>()
        var eventType = parser.eventType
        var currentEntry: VPlanEntry? = null
        var text: String? = null
        var inCorrectClassBlock = false
        var currentTag: String? = null

        while (eventType != XmlPullParser.END_DOCUMENT) {
            when (eventType) {
                XmlPullParser.START_TAG -> {
                    currentTag = parser.name
                    when {
                        currentTag.equals("Std", ignoreCase = true) && inCorrectClassBlock -> {
                            currentEntry = VPlanEntry()
                        }
                    }
                }
                XmlPullParser.TEXT -> {
                    text = parser.text
                }
                XmlPullParser.END_TAG -> {
                    val tagName = parser.name
                    when {
                        tagName.equals("Kurz", ignoreCase = true) -> {
                            if (text.equals(className, ignoreCase = true)) {
                                inCorrectClassBlock = true
                            }
                        }
                        tagName.equals("Std", ignoreCase = true) && inCorrectClassBlock -> {
                            currentEntry?.let { entries.add(it) }
                            currentEntry = null
                        }
                        tagName.equals("Kl", ignoreCase = true) -> {
                            inCorrectClassBlock = false
                        }
                        inCorrectClassBlock && currentEntry != null -> {
                            when (tagName) {
                                "St" -> currentEntry.count = text
                                "Fa" -> currentEntry.lesson = text
                                "Le" -> currentEntry.teacher = text
                                "Ra" -> currentEntry.place = text
                                "If" -> currentEntry.info = text
                                "Ku2" -> currentEntry.course = text
                            }
                        }
                    }
                    currentTag = null
                    text = null
                }
            }
            eventType = parser.next()
        }
        return entries
    }
}

data class VPlanEntry(
    var count: String? = null,
    var lesson: String? = null,
    var teacher: String? = null,
    var place: String? = null,
    var info: String? = null,
    var course: String? = null
)
