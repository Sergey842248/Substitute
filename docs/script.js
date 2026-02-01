let translations = {};

let currentLang = localStorage.getItem('language') || 'en';

function _(key) { return translations[currentLang][key] || key; }

async function loadTranslations() {
    const allTranslations = {};
    try {
        const [enResponse, deResponse] = await Promise.all([
            fetch('translations_en.json'),
            fetch('translations_de.json')
        ]);
        allTranslations.en = await enResponse.json();
        allTranslations.de = await deResponse.json();
        translations = allTranslations;
    } catch (error) {
        console.error('Error loading translations:', error);
        // Fallback translations
        translations = {
            en: {
                schoolNumber: 'School Number',
                username: 'Username',
                password: 'Password',
                customUrlOptional: 'Custom URL (optional)',
                useCustomUrl: 'Use Custom URL',
                loadClasses: 'Load Classes',
                selectClass: 'Select a Class',
                teacherManagement: 'Teacher Management',
                manageTeacherAbbreviations: 'Here you can manage teacher abbreviations',
                rooms: 'Rooms',
                selectDayTimeFindFreeRooms: 'Select a day and time to find free rooms.',
                search: 'Search',
                spaceDetails: 'Space Details',
                close: 'Close',
                backToClassOverview: 'Back to Class Overview',
                noInfoAvailable: 'No information available for this day',
                lessonNum: 'Lesson',
                teacherColon: 'Teacher:',
                spaceColon: 'Space:',
                timeColon: 'Time:',
                infoColon: 'Info:',
                generalInfo: 'General Information',
                info: 'Info:',
                selectTeacher: 'Select Teacher',
                planFor: 'Plan for',
                backToTeacherList: 'Back to Teacher List',
                spaceBold: 'Space',
                noFreeRooms: 'No free rooms available',
                occupiedRooms: 'Occupied rooms',
                detailsWillTakePlace: 'Following lessons take place:',
                lessonCol: 'Lesson',
                spaceCol: 'Space',
                timeCol: 'Time',
                classCol: 'Class',
                teacherCol: 'Teacher',
                vplanCredentials: 'VPlan Credentials',
                settings: 'Settings',
                changeAccessData: 'Change your credentials',
                showAnalytics: 'Show Analytics',
                deleteData: 'Delete Data',
                language: 'Language',
                english: 'English',
                german: 'Deutsch',
                appInfo: 'App Info',
                substituteOrganizer: 'Substitute - Organizer App',
                reportBug: 'Report a Bug',
                requestFeature: 'Request a Feature',
                changelog: 'Changelog',
                tabVPlan: 'SPlan',
                tabTeachers: 'Teachers',
                tabRooms: 'Rooms',
                tabSettings: 'Settings',
                fillCredentials: 'Please fill in the credentials!',
                errorLoadingClasses: 'Error loading classes: ',
                credentialsSaved: 'Credentials saved!',
                save: 'Save',
                ok: 'OK',
                yes: 'Yes',
                no: 'No',
                        deleteAllData: 'Delete all saved data?',
                        errorLoadingTeachers: 'Error loading teachers: ',
                        errorLoadingTeacherPlan: 'Error loading teacher plan: ',
                        errorLoadingSpaceDetails: 'Error loading space details.',
                        noPlanForDate: 'No plan available for the selected date.',
                        noLessonInSpaceAtTime: 'No lesson taking place in this space at this time.',
                        selectDateTime: 'Please select a date and time.',
                        analyticsSettings: 'Analytics Settings',
                savedSchoolNumber: 'Saved School Number',
                lastUsed: 'Last Used',
                apiStatus: 'API Status',
                ready: 'Ready',
                notConfigured: 'Not configured',
                searchTeacher: 'Search for teacher abbreviation'
            },
            de: {
                schoolNumber: 'Schulnummer',
                username: 'Benutzername',
                password: 'Passwort',
                customUrlOptional: 'Benutzerdefinierte URL (optional)',
                useCustomUrl: 'Benutzerdefinierte URL verwenden',
                loadClasses: 'Klassen laden',
                selectClass: 'Wähle eine Klasse',
                teacherManagement: 'Lehrerverwaltung',
                manageTeacherAbbreviations: 'Hier können Lehrerkürzel verwaltet werden',
                rooms: 'Räume',
                selectDayTimeFindFreeRooms: 'Wähle einen Tag und eine Zeit, um freie Räume zu finden.',
                search: 'Suchen',
                spaceDetails: 'Raum Details',
                close: 'Schließen',
                backToClassOverview: 'Zurück zur Klassenübersicht',
                noInfoAvailable: 'Für diesen Tag sind keine Informationen verfügbar',
                lessonNum: 'Stunde',
                teacherColon: 'Lehrer:',
                spaceColon: 'Raum:',
                timeColon: 'Zeit:',
                infoColon: 'Info:',
                generalInfo: 'Allgemeine Informationen',
                info: 'Info:',
                selectTeacher: 'Lehrer auswählen',
                planFor: 'Plan für',
                backToTeacherList: 'Zurück zur Lehrerliste',
                spaceBold: 'Raum',
                noFreeRooms: 'Keine freien Räume verfügbar',
                occupiedRooms: 'Besetzte Räume',
                detailsWillTakePlace: 'Folgende Unterrichtsstunden finden statt:',
                lessonCol: 'Stunde',
                spaceCol: 'Raum',
                timeCol: 'Zeit',
                classCol: 'Klasse',
                teacherCol: 'Lehrer',
                vplanCredentials: 'VPlan Anmeldedaten',
                settings: 'Einstellungen',
                changeAccessData: 'Zugangsdaten ändern',
                showAnalytics: 'Analysen anzeigen',
                deleteData: 'Daten löschen',
                language: 'Sprache',
                english: 'Englisch',
                german: 'Deutsch',
                appInfo: 'App Info',
                substituteOrganizer: 'Substitute - Vertretungsplan App',
                reportBug: 'Report a Bug',
                requestFeature: 'Request a Feature',
                changelog: 'Changelog',
                tabVPlan: 'VPlan',
                tabTeachers: 'Lehrer',
                tabRooms: 'Räume',
                tabSettings: 'Einstellungen',
                fillCredentials: 'Bitte füllen Sie die Anmeldedaten aus!',
                errorLoadingClasses: 'Fehler beim Laden der Klassen: ',
                credentialsSaved: 'Anmeldedaten gespeichert!',
                save: 'Speichern',
                ok: 'OK',
                yes: 'Ja',
                no: 'Nein',
                deleteAllData: 'Alle gespeicherten Daten löschen?',
                errorLoadingTeachers: 'Fehler beim Laden der Lehrer: ',
                errorLoadingTeacherPlan: 'Fehler beim Laden der Lehrerplandaten: ',
                errorLoadingSpaceDetails: 'Fehler beim Laden der Raumdetails.',
                noPlanForDate: 'Kein Plan für das ausgewählte Datum verfügbar.',
                noLessonInSpaceAtTime: 'Zu diesem Zeitpunkt findet keine Unterrichtsstunde in diesem Raum statt.',
                        selectDateTime: 'Bitte wähle ein Datum und eine Uhrzeit.',
                        analyticsSettings: 'Analytics Settings',
                savedSchoolNumber: 'Gespeicherte Schulnummer',
                lastUsed: 'Zuletzt verwendet',
                apiStatus: 'API-Status',
                ready: 'Bereit',
                notConfigured: 'Nicht konfiguriert',
                searchTeacher: 'Suche nach Lehrerkürzel'
            }
        };
    }
    currentLang = localStorage.getItem('language') || 'en';
    updateTexts();
}

let cachedXmlData = ''; // Cache for the fetched XML data for the current day
let cachedTeacherList = []; // Cache for the teacher list
let cachedCourses = []; // Cache for courses with visibility state

// --- State for Date Navigation ---
let currentDate = new Date();
let currentView = { type: null, name: null }; // Tracks what is being viewed, e.g., { type: 'class', name: '10A' }

// Function to calculate week number like in the Android app
function weekNumber(date) {
    const d = new Date(date.getFullYear(), 0, 1);
    const dayOfYear = Math.floor((date - d) / (24 * 60 * 60 * 1000)) + 1;
    const weekday = date.getDay() === 0 ? 7 : date.getDay(); // Convert Sunday 0 to 7
    return Math.floor((dayOfYear - weekday + 10) / 7);
}

// Function to find the latest available date with a substitute plan
async function findLatestDate() {
    let checkDate = new Date(); // Start from today
    let maxDays = 7; // Check up to 7 days ahead
    let latest = null;

    for (let i = 0; i <= maxDays; i++) {
        try {
            const xmlText = await fetchPlanForDate(checkDate);
            if (xmlText !== null) {
                latest = new Date(checkDate);
            }
        } catch (error) {
            // If there's an error (other than 404), skip this day
            console.error(`Error checking plan for ${formatDateForDisplay(checkDate)}:`, error);
        }
        checkDate.setDate(checkDate.getDate() + 1);
    }

    return latest || new Date(); // Return latest found, or today if none
}

// Load saved credentials on page load
window.onload = async function() {
    loadCredentials();
    await loadTranslations();
    const favoriteClass = localStorage.getItem('favoriteClass');
    const schoolnumber = localStorage.getItem('vplanSchoolnumber');

    if (favoriteClass && schoolnumber) {
        loadPlanForFavoriteClass(favoriteClass);
    }
};

async function loadPlanForFavoriteClass(className) {
    const schoolnumber = localStorage.getItem('vplanSchoolnumber');
    const username = localStorage.getItem('vplanUsername');
    const password = localStorage.getItem('vplanPassword');
    const customUrl = localStorage.getItem('customUrl');

    // Find the latest available date with a substitute plan
    currentDate = await findLatestDate();

    try {
        const xmlText = await fetchPlanForDate(currentDate);
        if (xmlText) {
            cachedXmlData = xmlText; // Cache the data
            const { lessons, planDate } = parseLessons(xmlText, className);
            displayLessons(lessons, formatDateForDisplay(currentDate), className, xmlText);
        } else {
            displayLessons([], formatDateForDisplay(currentDate), className, null);
        }
        currentView = { type: 'class', name: className };

        document.getElementById('class-list-container').style.display = 'block';
        document.getElementById('login-form').style.display = 'none';

    } catch (error) {
        console.error('Error auto-loading favorite class plan:', error);
        document.getElementById('login-form').style.display = 'block';
    }
}

function loadCredentials() {
    const schoolnumber = localStorage.getItem('vplanSchoolnumber');
    const username = localStorage.getItem('vplanUsername');
    const password = localStorage.getItem('vplanPassword');
    const customUrl = localStorage.getItem('customUrl');

    if (schoolnumber) document.getElementById('schoolnumber').value = schoolnumber;
    if (username) document.getElementById('username').value = username;
    if (password) document.getElementById('password').value = password;
    if (customUrl) document.getElementById('customUrl').value = customUrl;
}

function autoSaveCredentials() {
    const schoolnumber = document.getElementById('schoolnumber').value;
    const username = document.getElementById('username').value;
    const password = document.getElementById('password').value;
    const customUrl = document.getElementById('customUrl').value;

    localStorage.setItem('vplanSchoolnumber', schoolnumber);
    localStorage.setItem('vplanUsername', username);
    localStorage.setItem('vplanPassword', password);
    localStorage.setItem('customUrl', customUrl);
}

function saveCredentials() {
    const schoolnumber = document.getElementById('schoolnumber').value;
    const username = document.getElementById('username').value;
    const password = document.getElementById('password').value;
    const customUrl = document.getElementById('customUrl').value;

    localStorage.setItem('vplanSchoolnumber', schoolnumber);
    localStorage.setItem('vplanUsername', username);
    localStorage.setItem('vplanPassword', password);
    localStorage.setItem('customUrl', customUrl);

    showMessageModal('Anmeldedaten gespeichert!');
}

function toggleCustomUrl() {
    const customUrlInput = document.getElementById('customUrl');
    const isVisible = customUrlInput.style.display !== 'none';
    customUrlInput.style.display = isVisible ? 'none' : 'block';
}

async function loadClasses(forceRefresh = false) {
    const schoolnumber = document.getElementById('schoolnumber').value;
    const username = document.getElementById('username').value;
    const password = document.getElementById('password').value;
    const customUrl = document.getElementById('customUrl').value;

    if (!schoolnumber || (!username && !password && !customUrl)) {
        showMessageModal('Bitte füllen Sie die Anmeldedaten aus!');
        return;
    }

    const cachedClasses = localStorage.getItem('cachedClasses');
    if (cachedClasses && !forceRefresh) {
        const classList = JSON.parse(cachedClasses);
        displayClasses(classList);
        document.getElementById('class-list-container').style.display = 'block';
        document.getElementById('login-form').style.display = 'none';
        return;
    }

    try {
const proxy = 'https://cors.parsafallah09.workers.dev/?url=';
let url;
let headers = {};

if (customUrl) {
    url = `${proxy}${customUrl}Klassen.xml`;
} else {
    url = `${proxy}https://www.stundenplan24.de/${schoolnumber}/mobil/mobdaten/Klassen.xml`;
    const credentials = btoa(`${username}:${password}`);
    headers['Authorization'] = `Basic ${credentials}`;
}

        const response = await fetch(url, {
            method: 'GET',
            headers: headers
        });

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }

const xmlText = await response.text();
cachedXmlData = xmlText; // Cache the XML data
const classList = await parseClasses(xmlText);
localStorage.setItem('cachedClasses', JSON.stringify(classList)); // Save classes to localStorage

displayClasses(classList);

        document.getElementById('class-list-container').style.display = 'block';
        document.getElementById('login-form').style.display = 'none';

    } catch (error) {
        showMessageModal('Fehler beim Laden der Klassen: ' + error.message);
        console.error('Error loading classes:', error);
    }
}

function parseClasses(xmlText) {
    const parser = new DOMParser();
    const xmlDoc = parser.parseFromString(xmlText, 'text/xml');
    const classes = xmlDoc.querySelectorAll('Kl');
    const classList = [];

    classes.forEach(cls => {
        const kurz = cls.querySelector('Kurz')?.textContent;
        if (kurz) {
            classList.push(kurz);
        }
    });

    return classList;
}

function displayClasses(classList) {
    const classListElement = document.getElementById('class-list');
    classListElement.innerHTML = '';

    classList.forEach(className => {
        const classItem = document.createElement('div');
        classItem.className = 'class-item';
        classItem.innerHTML = `
            <strong>${className}</strong>
        `;
        classItem.onclick = () => loadClassDetails(className);
        classListElement.appendChild(classItem);
    });
}

async function loadClassDetails(className, fromDateChange = false) {
    localStorage.setItem('favoriteClass', className);

    if (!fromDateChange) {
        currentDate = new Date(); // Reset to today
        currentDate = await findLatestDate(); // Then find the latest available date
    }
    currentView = { type: 'class', name: className };
    

    try {
        const xmlText = await fetchPlanForDate(currentDate);
    if (xmlText) {
        const { lessons, planDate } = parseLessons(xmlText, className);
        displayLessons(lessons, formatDateForDisplay(currentDate), currentView.name, xmlText);
    } else {
        displayLessons([], formatDateForDisplay(currentDate), currentView.name, null); // Show empty plan if no data
    }
    } catch (error) {
        console.error('Fehler beim Laden der Plandaten für dieses Datum: ', error);
        displayLessons([], formatDateForDisplay(currentDate), currentView.name, null); // Show empty plan on error
    }
}

function getCurrentDateYYYYMMDD() {
    const date = new Date();
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}${month}${day}`;
}

function parseLessons(xmlText, className) {
    const parser = new DOMParser();
    const xmlDoc = parser.parseFromString(xmlText, 'text/xml');
    
    const kopf = xmlDoc.querySelector('Kopf');
    const planDate = kopf?.querySelector('DatumPlan')?.textContent;

    const classes = xmlDoc.querySelectorAll('Kl');

    for (let i = 0; i < classes.length; i++) {
        const kurz = classes[i].querySelector('Kurz');
        if (kurz && kurz.textContent === className) {
            const stunden = classes[i].querySelectorAll('Std');
            const lessons = [];

            stunden.forEach(std => {
                const st = std.querySelector('St')?.textContent;
                const fa = std.querySelector('Fa')?.textContent;
                const regel = std.querySelector('If')?.textContent;
                const beginn = std.querySelector('Beginn')?.textContent;
                const ende = std.querySelector('Ende')?.textContent;
                const raElement = std.querySelector('Ra');
                const ra = raElement?.textContent;
                const raChanged = raElement?.hasAttribute('RaAe') || false;
                const le = std.querySelector('Le')?.textContent;

                if (st && fa) {
                    lessons.push({
                        stunde: st,
                        fach: fa,
                        regel: regel,
                        beginn: beginn || '',
                        ende: ende || '',
                        raum: ra || '',
                        raumChanged: raChanged,
                        lehrer: le || ''
                    });
                }
            });

            return { lessons: lessons, planDate: planDate };
        }
    }

    return { lessons: [], planDate: planDate };
}

function parseGeneralInfo(xmlText) {
    const parser = new DOMParser();
    const xmlDoc = parser.parseFromString(xmlText, 'text/xml');

    // Parse ZusatzInfo > ZiZeile elements (same as the app)
    const generalInfo = [];

    const zusatzInfo = xmlDoc.querySelector('ZusatzInfo');
    if (zusatzInfo) {
        const ziZeilen = zusatzInfo.querySelectorAll('ZiZeile');
        ziZeilen.forEach(element => {
            const text = element.textContent?.trim();
            if (text) {
                generalInfo.push(text);
            }
        });

        // Remove trailing empty entries (same logic as app)
        while (generalInfo.length > 0 && generalInfo[generalInfo.length - 1].trim() === '') {
            generalInfo.pop();
        }
    }

    return generalInfo;
}

function displayLessons(lessons, dateString, className, xmlText) {
    const container = document.getElementById('class-list-container');
    container.innerHTML = `
        <div style="display: flex; justify-content: space-between; align-items: center; padding: 0 10px;">
            <button onclick="changeDay(-1, '${className}')" style="font-size: 24px; background: none; border: none; color: #AF69EE; cursor: pointer;"><</button>
            <h3 style="margin: 0; text-align: center; cursor: pointer;" onclick="showWeek()">${dateString}</h3>
            <button onclick="changeDay(1, '${className}')" style="font-size: 24px; background: none; border: none; color: #AF69EE; cursor: pointer;">></button>
        </div>
        <div id="lessons"></div>
        <div id="general-info"></div>
        <button onclick="backToClasses()">${_('backToClassOverview')}</button>
    `;

    const lessonsElement = document.getElementById('lessons');

    // Filter lessons based on hidden courses
    const hiddenCourses = getHiddenCourses();
    const filteredLessons = lessons.filter(lesson => !hiddenCourses.includes(lesson.fach));

    if (filteredLessons.length === 0) {
        lessonsElement.innerHTML = `<p>${_('noInfoAvailable')}</p>`;
    } else {
        filteredLessons.forEach(lesson => {
            const lessonItem = document.createElement('div');
            lessonItem.className = 'class-item';
            if (lesson.regel && lesson.regel.trim() !== '') {
                lessonItem.style.backgroundColor = 'rgba(139, 0, 0, 0.6)';
            }
    const roomStyle = lesson.raumChanged ? 'color: #ff4444; font-weight: bold;' : '';
    lessonItem.innerHTML = `
        <strong>${_('lessonNum')} ${lesson.stunde}: ${lesson.fach}</strong>
        <div>${_('teacherColon')} ${lesson.lehrer}</div>
        <div>${_('spaceColon')} <span style="${roomStyle}">${lesson.raum}</span></div>
        <div>${_('timeColon')} ${lesson.beginn} - ${lesson.ende}</div>
        <div>${lesson.regel ? _('infoColon') + lesson.regel : ''}</div>
    `;
            lessonsElement.appendChild(lessonItem);
        });
    }

    // Display general information at the bottom if available
    if (xmlText) {
        const generalInfo = parseGeneralInfo(xmlText);
        const generalInfoElement = document.getElementById('general-info');

        if (generalInfo.length > 0) {
            generalInfoElement.innerHTML = `<h4 style="margin-top: 20px; color: #AF69EE;">${_('generalInfo')}</h4>`;

            generalInfo.forEach(info => {
                const infoItem = document.createElement('div');
                infoItem.className = 'class-item';
                infoItem.style.backgroundColor = '#2a2a3c';
                infoItem.style.borderColor = '#AF69EE';
                infoItem.style.borderWidth = '2px';
                infoItem.innerHTML = `${info}`;
                generalInfoElement.appendChild(infoItem);
            });
        }
    }
}

function backToClasses() {
    document.getElementById('class-list-container').innerHTML = `
        <h2>${_('selectClass')}</h2>
        <div id="class-list"></div>
    `;
    if (cachedXmlData) {
        const classList = parseClasses(cachedXmlData);
        displayClasses(classList);
    } else {
        // Fallback if cache is empty for some reason
        document.getElementById('login-form').style.display = 'block';
        document.getElementById('class-list-container').style.display = 'none';
    }
    // Remove manual save button when leaving settings view
    removeManualSaveButton();
}

function removeManualSaveButton() {
    const manualSaveButton = document.getElementById('manual-save-button');
    if (manualSaveButton) {
        manualSaveButton.remove();
    }
}

function setTab(tabIndex) {
    const tabs = document.querySelectorAll('.tab-content');
    tabs.forEach(tab => tab.style.display = 'none');

    const navItems = document.querySelectorAll('.nav-item');
    navItems.forEach(item => item.classList.remove('active'));
    navItems[tabIndex].classList.add('active');

    const tabIds = ['tab-vplan', 'tab-teacher', 'tab-freerooms', 'tab-settings'];
    document.getElementById(tabIds[tabIndex]).style.display = 'block';

    // Pre-fill date and time and auto-load teachers/freerooms when switching tabs
    if (tabIndex === 1) {
        loadTeachers();
    }
    if (tabIndex === 3) {
        const now = new Date();
        const year = now.getFullYear();
        const month = String(now.getMonth() + 1).padStart(2, '0');
        const day = String(now.getDate()).padStart(2, '0');
        const hours = String(now.getHours()).padStart(2, '0');
        const minutes = String(now.getMinutes()).padStart(2, '0');

        const dateInput = document.getElementById('freerooms-date');
        if (!dateInput.value) {
            dateInput.value = `${year}-${month}-${day}`;
        }

        const timeInput = document.getElementById('freerooms-time');
        if (!timeInput.value) {
            timeInput.value = `${hours}:${minutes}`;
        }
    }
}

async function loadTeachers(forceRefresh = false) {
    const schoolnumber = document.getElementById('schoolnumber').value;
    const username = document.getElementById('username').value;
    const password = document.getElementById('password').value;
    const customUrl = document.getElementById('customUrl').value;

    if (!schoolnumber || (!username && !password && !customUrl)) {
        showMessageModal('Bitte füllen Sie die Anmeldedaten aus!');
        return;
    }

    const cachedTeachers = localStorage.getItem('cachedTeachers');
    if (cachedTeachers && !forceRefresh) {
        const teacherList = JSON.parse(cachedTeachers);
        cachedTeacherList = teacherList;
        displayTeachers(teacherList, '');
        return;
    }

    try {
        const proxy = 'https://cors.parsafallah09.workers.dev/?url=';
        let url;
        let headers = {};

        if (customUrl) {
            url = `${proxy}${customUrl}Klassen.xml`;
        } else {
            url = `${proxy}https://www.stundenplan24.de/${schoolnumber}/mobil/mobdaten/Klassen.xml`;
            const credentials = btoa(`${username}:${password}`);
            headers['Authorization'] = `Basic ${credentials}`;
        }

        const response = await fetch(url, {
            method: 'GET',
            headers: headers
        });

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }

        const xmlText = await response.text();
        // Ensure class XML is cached if teachers are loaded first
        if (!cachedXmlData) cachedXmlData = xmlText; 
        
        const teacherList = parseTeachers(xmlText);
        cachedTeacherList = teacherList; // Cache the teacher list in memory
        localStorage.setItem('cachedTeachers', JSON.stringify(teacherList)); // Cache in localStorage
        displayTeachers(teacherList, '');

    } catch (error) {
        showMessageModal('Fehler beim Laden der Lehrer: ' + error.message);
        console.error('Error loading teachers:', error);
    }
}

function parseTeachers(xmlText) {
    const parser = new DOMParser();
    const xmlDoc = parser.parseFromString(xmlText, 'text/xml');
    const kkzElements = xmlDoc.querySelectorAll('KKz');
    const teachers = new Set(); 

    kkzElements.forEach(kkz => {
        if (kkz.attributes.length > 0) {
            const teacherShort = kkz.attributes[0].value;
            if (teacherShort) {
                teachers.add(teacherShort);
            }
        }
    });

    return Array.from(teachers).sort();
}

function displayTeachers(teacherList, filter = '') {
    const teacherListElement = document.getElementById('teacher-list');
    teacherListElement.innerHTML = '';

    const filteredList = teacherList.filter(teacher => teacher.toLowerCase().includes(filter.toLowerCase()));

    filteredList.forEach(teacherName => {
        const teacherItem = document.createElement('div');
        teacherItem.className = 'class-item';
        teacherItem.style.cursor = 'pointer';
        teacherItem.innerHTML = `<strong>${teacherName}</strong>`;
        teacherItem.onclick = () => loadTeacherDetails(teacherName);
        teacherListElement.appendChild(teacherItem);
    });

    teacherListElement.style.display = 'block';
}

function filterTeachers() {
    const filter = document.getElementById('teacher-search').value;
    displayTeachers(cachedTeacherList, filter);
}

async function loadTeacherDetails(teacherName, fromDateChange = false) {
    if (!fromDateChange) {
        currentDate = new Date(); // Reset to today
        currentDate = await findLatestDate(); // Then find the latest available date
    }
    currentView = { type: 'teacher', name: teacherName };

    try {
        const xmlText = await fetchPlanForDate(currentDate);
        if (xmlText) {
            const lessons = parseTeacherLessons(xmlText, teacherName);
            displayTeacherLessons(teacherName, lessons, formatDateForDisplay(currentDate));
        } else {
            displayTeacherLessons(teacherName, [], formatDateForDisplay(currentDate));
        }
    } catch (error) {
        console.error('Fehler beim Laden der Lehrerplandaten: ', error);
        displayTeacherLessons(teacherName, [], formatDateForDisplay(currentDate));
    }
}

function normalizeVPlanInfoText(text) {
    if (!text) return '';
    return text
        .toString()
        .toLowerCase()
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .replace(/ß/g, 'ss')
        .trim();
}

function isCancelledLessonInfo(infoText) {
    const t = normalizeVPlanInfoText(infoText);
    if (!t) return false;

    if (/\b(entfall|entfallt|entfaellt|ausfall|ausgefallen)\b/.test(t)) return true;

    // Handles variants like "fällt heute aus" / "fällt wegen ... aus"
    return /\b(fallt|faellt)\b/.test(t) && /\baus\b/.test(t);
}

function parseTeacherLessons(xmlText, teacherName) {
    const parser = new DOMParser();
    const xmlDoc = parser.parseFromString(xmlText, 'text/xml');
    const classes = xmlDoc.querySelectorAll('Kl');
    const lessons = [];

    const normalizedTeacher = (teacherName || '').trim().toLowerCase();

    classes.forEach(cls => {
        const className = cls.querySelector('Kurz')?.textContent;
        const stunden = cls.querySelectorAll('Std');

        stunden.forEach(std => {
            const lehrer = std.querySelector('Le')?.textContent;
            if (!lehrer) return;

            if (lehrer.trim().toLowerCase() === normalizedTeacher) {
                const st = std.querySelector('St')?.textContent;
                const fa = std.querySelector('Fa')?.textContent;
                const regel = std.querySelector('If')?.textContent;

                if (isCancelledLessonInfo(regel)) return;

                const beginn = std.querySelector('Beginn')?.textContent;
                const ende = std.querySelector('Ende')?.textContent;
                const raElement = std.querySelector('Ra');
                const ra = raElement?.textContent;
                const raChanged = raElement?.hasAttribute('RaAe') || false;

                if (st && fa) {
                    lessons.push({
                        klasse: className,
                        stunde: st,
                        fach: fa,
                        regel: regel || '',
                        beginn: beginn || '',
                        ende: ende || '',
                        raum: ra || '',
                        raumChanged: raChanged,
                        lehrer: lehrer
                    });
                }
            }
        });
    });

    lessons.sort((a, b) => {
        const aNum = parseInt(a.stunde, 10);
        const bNum = parseInt(b.stunde, 10);

        if (!Number.isNaN(aNum) && !Number.isNaN(bNum)) {
            return aNum - bNum;
        }
        return a.stunde.localeCompare(b.stunde);
    });

    return lessons;
}

function displayTeacherLessons(teacherName, lessons, dateString) {
    const container = document.querySelector('#tab-teacher .form-container');
    container.innerHTML = `
        <div style="display: flex; justify-content: space-between; align-items: center; padding: 0 10px;">
            <button onclick="changeDay(-1, '${teacherName}')" style="font-size: 24px; background: none; border: none; color: #AF69EE; cursor: pointer;"><</button>
            <h3 style="margin: 0; text-align: center;">${_('planFor')} ${teacherName}<br><small style="cursor: pointer;" onclick="showWeek()">${dateString}</small></h3>
            <button onclick="changeDay(1, '${teacherName}')" style="font-size: 24px; background: none; border: none; color: #AF69EE; cursor: pointer;">></button>
        </div>
        <div id="teacher-lessons"></div>
        <button onclick="backToTeachers()">${_('backToTeacherList')}</button>
    `;

    const lessonsElement = document.getElementById('teacher-lessons');

    if (lessons.length === 0) {
        lessonsElement.innerHTML = `<p>${_('noInfoAvailable')}</p>`;
        return;
    }

    lessons.forEach(lesson => {
        const lessonItem = document.createElement('div');
        lessonItem.className = 'class-item';
        if (lesson.regel && lesson.regel.trim() !== '') {
            lessonItem.style.backgroundColor = 'rgba(139, 0, 0, 0.6)';
        }
        const roomStyle = lesson.raumChanged ? 'color: #ff4444; font-weight: bold;' : '';
        lessonItem.innerHTML = `
            <strong>${_('classCol')} ${lesson.klasse}, ${_('lessonNum')} ${lesson.stunde}: ${lesson.fach}</strong>
            <div>${_('spaceColon')} <span style="${roomStyle}">${lesson.raum}</span></div>
            <div>${_('timeColon')} ${lesson.beginn} - ${lesson.ende}</div>
            <div>${lesson.regel ? _('infoColon') + lesson.regel : ''}</div>
        `;
        lessonsElement.appendChild(lessonItem);
    });
}

function backToTeachers() {
    const container = document.getElementById('tab-teacher').querySelector('.form-container');
    container.innerHTML = `
        <h2>${_('teacherManagement')}</h2>
        <p>${_('manageTeacherAbbreviations')}</p>
        <input type="text" id="teacher-search" placeholder="${_('searchTeacher')}" oninput="filterTeachers()">
        <div id="teacher-list" class="class-list"></div>
    `;
    displayTeachers(cachedTeacherList, '');
}

function showSettings() {
    setTab(0);
    document.getElementById('login-form').style.display = 'block';
    document.getElementById('class-list-container').style.display = 'none';

    // Add save button for manual credential changes
    const loginForm = document.getElementById('login-form');
    const existingSaveButton = document.getElementById('manual-save-button');
    if (!existingSaveButton) {
        const saveButton = document.createElement('button');
        saveButton.id = 'manual-save-button';
        saveButton.textContent = 'Speichern';
        saveButton.onclick = saveCredentials;
        saveButton.style.marginTop = '10px';
        loginForm.appendChild(saveButton);
    }
}

// --- Date Navigation Helper Functions ---

function isToday(date) {
    const today = new Date();
    return date.getDate() === today.getDate() &&
           date.getMonth() === today.getMonth() &&
           date.getFullYear() === today.getFullYear();
}

function formatDateForURL(date) {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}${month}${day}`;
}

function formatDateForDisplay(date) {
    const locale = currentLang === 'de' ? 'de-DE' : 'en-GB';
    return date.toLocaleDateString(locale, { weekday: 'short', year: 'numeric', month: '2-digit', day: '2-digit' });
}

function changeDay(offset, name) {
    currentDate.setDate(currentDate.getDate() + offset);
    
    if (offset > 0 && currentDate.getDay() === 6) currentDate.setDate(currentDate.getDate() + 2);
    if (offset > 0 && currentDate.getDay() === 0) currentDate.setDate(currentDate.getDate() + 1);
    if (offset < 0 && currentDate.getDay() === 0) currentDate.setDate(currentDate.getDate() - 2);
    if (offset < 0 && currentDate.getDay() === 6) currentDate.setDate(currentDate.getDate() - 1);

    if (currentView.type === 'class') {
        loadClassDetails(name, true);
    } else if (currentView.type === 'teacher') {
        loadTeacherDetails(name, true);
    }
}

async function fetchPlanForDate(date) {
    const schoolnumber = document.getElementById('schoolnumber').value;
    const username = document.getElementById('username').value;
    const password = document.getElementById('password').value;
    const customUrl = document.getElementById('customUrl').value;
    
    const dateUrlPart = `PlanKl${formatDateForURL(date)}.xml`;
    
    try {
const proxy = 'https://cors.parsafallah09.workers.dev/?url=';
let url;
let headers = {};

if (customUrl) {
    url = `${proxy}${customUrl}${dateUrlPart}`;
} else {
    url = `${proxy}https://www.stundenplan24.de/${schoolnumber}/mobil/mobdaten/${dateUrlPart}`;
    const credentials = btoa(`${username}:${password}`);
    headers['Authorization'] = `Basic ${credentials}`;
}

        const response = await fetch(url, { method: 'GET', headers: headers });

        if (response.status === 404) {
            return null; // No plan for this day, not an error
        }
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        return await response.text();

    } catch (error) {
        console.error(`Error fetching plan for ${formatDateForDisplay(date)}:`, error);
        throw error; // Rethrow to be caught by the caller
    }
}

function showAnalytics() {
    const info = document.getElementById('settings-info');
    const savedSchool = localStorage.getItem('vplanSchoolnumber');
    info.innerHTML = `
        <div class="class-item">
            <strong>${_('analyticsSettings')}</strong>
            <div>${_('savedSchoolNumber')}: ${savedSchool || _('notConfigured')}</div>
            <div>${_('lastUsed')}: ${new Date().toLocaleDateString(currentLang === 'de' ? 'de-DE' : 'en-GB', { year: 'numeric', month: '2-digit', day: '2-digit' })}</div>
            <div>${_('apiStatus')}: ${savedSchool ? _('ready') : _('notConfigured')}</div>
        </div>
    `;
}

async function clearData() {
    if (await showConfirmModal('Alle gespeicherten Daten löschen?')) {
        localStorage.clear();
        location.reload();
    }
}

function showInfo() {
    document.getElementById('info-modal').style.display = 'block';
}

function closeModal() {
    document.getElementById('info-modal').style.display = 'none';
    document.getElementById('room-details-modal').style.display = 'none';
    document.getElementById('message-modal').style.display = 'none';
    document.getElementById('confirm-modal').style.display = 'none';
    document.getElementById('week-modal').style.display = 'none';
}

// Custom popup functions
let confirmResolve;

function showMessageModal(message) {
    document.getElementById('message-text').textContent = message;
    document.getElementById('message-modal').style.display = 'block';
}

function closeMessageModal() {
    document.getElementById('message-modal').style.display = 'none';
}

function showConfirmModal(message) {
    document.getElementById('confirm-text').textContent = message;
    document.getElementById('confirm-modal').style.display = 'block';
    return new Promise(resolve => {
        confirmResolve = resolve;
    });
}

function resolveConfirm(result) {
    document.getElementById('confirm-modal').style.display = 'none';
    if (confirmResolve) {
        confirmResolve(result);
    }
}



function selectDate() {
    const dateInput = document.getElementById('freerooms-date');
    if (typeof dateInput.showPicker === 'function') {
        dateInput.showPicker();
    } else {
        // Fallback: make input visible and click it
        dateInput.style.display = 'block';
        dateInput.focus();
        dateInput.click();
    }
}

function selectTime() {
    const timeInput = document.getElementById('freerooms-time');
    if (typeof timeInput.showPicker === 'function') {
        timeInput.showPicker();
    } else {
        // Fallback: make input visible and click it
        timeInput.style.display = 'block';
        timeInput.focus();
        timeInput.click();
    }
}

function showFreeRooms() {
    setTab(3);
}

async function findFreeRooms() {
    const date = document.getElementById('freerooms-date').value;
    const time = document.getElementById('freerooms-time').value;

    if (!date || !time) {
        showMessageModal('Bitte wähle ein Datum und eine Uhrzeit.');
        return;
    }

    const selectedDateTime = new Date(`${date}T${time}`);
    const xmlText = await fetchPlanForDate(selectedDateTime);

    if (!xmlText) {
        showMessageModal('Kein Plan für das ausgewählte Datum verfügbar.');
        return;
    }

    const { freeRooms, occupiedRooms } = parseRoomStatus(xmlText, selectedDateTime);
    displayFreeRooms(freeRooms, occupiedRooms);
}

function parseRoomStatus(xmlText, selectedTime) {
    const parser = new DOMParser();
    const xmlDoc = parser.parseFromString(xmlText, 'text/xml');
    const classes = xmlDoc.querySelectorAll('Kl');
    const allRooms = new Set();
    const occupiedRooms = new Set();

    // Extract all unique numeric rooms from the plan
    classes.forEach(cls => {
        const stunden = cls.querySelectorAll('Std');
        stunden.forEach(std => {
            const room = std.querySelector('Ra')?.textContent;
            if (room && room.trim() !== '---' && room.trim() !== 'Gang') {
                // Clean room name like in the app (remove prefixes H1, H2, H3, E)
                let editRoom = room.replace(/H[123]|E/g, '');
                if (/^\d+$/.test(editRoom)) { // Check if it's a numeric room
                    allRooms.add(parseInt(editRoom));
                }
            }
        });
    });

    // Determine which rooms are occupied at the selected time
    classes.forEach(cls => {
        const stunden = cls.querySelectorAll('Std');
        stunden.forEach(std => {
            const beginn = std.querySelector('Beginn')?.textContent;
            const ende = std.querySelector('Ende')?.textContent;
            const room = std.querySelector('Ra')?.textContent;

            if (beginn && ende && room) {
                // Clean room name
                let editRoom = room.replace(/H[123]|E/g, '');
                if (/^\d+$/.test(editRoom)) {
                    const roomNum = parseInt(editRoom);

                    // Create Date objects for comparison
                    const lessonStart = new Date(`${selectedTime.toDateString()} ${beginn}`);
                    const lessonEnd = new Date(`${selectedTime.toDateString()} ${ende}`);

                    // Check if the selected time falls within the lesson's duration
                    if (selectedTime >= lessonStart && selectedTime < lessonEnd) {
                        occupiedRooms.add(roomNum);
                    }
                }
            }
        });
    });

    const freeRooms = [...allRooms].filter(room => !occupiedRooms.has(room)).sort((a, b) => a - b);
    const occupiedRoomsArray = [...occupiedRooms].sort((a, b) => a - b);

    return { freeRooms, occupiedRooms: occupiedRoomsArray };
}

function displayFreeRooms(freeRooms, occupiedRooms) {
    const freeRoomsList = document.getElementById('freerooms-list');
    freeRoomsList.innerHTML = '';

    if (freeRooms.length > 0) {
        freeRoomsList.innerHTML += `<h3>${_('rooms')}</h3>`;
        freeRooms.forEach(room => {
            const roomItem = document.createElement('div');
            roomItem.className = 'class-item';
            roomItem.style.borderColor = '#AF69EE';
            roomItem.style.borderWidth = '2px';
            roomItem.style.cursor = 'pointer';
            roomItem.innerHTML = `<strong>${room}</strong>`;
            roomItem.onclick = () => showRoomDetails(room);
            freeRoomsList.appendChild(roomItem);
        });
    } else {
        freeRoomsList.innerHTML += `<h3>${_('noFreeRooms')}</h3>`;
    }

    if (occupiedRooms.length > 0) {
        freeRoomsList.innerHTML += `<h3>${_('occupiedRooms')}</h3>`;
        occupiedRooms.forEach(room => {
            const roomItem = document.createElement('div');
            roomItem.className = 'class-item';
            roomItem.style.cursor = 'pointer';
            roomItem.innerHTML = `<strong>${room}</strong>`;
            roomItem.onclick = () => showRoomDetails(room);
            freeRoomsList.appendChild(roomItem);
        });
    }

    freeRoomsList.style.display = 'block';
}

function showRoomDetails(roomNumber) {
    const date = document.getElementById('freerooms-date').value;
    const time = document.getElementById('freerooms-time').value;

    if (!date || !time) {
        showMessageModal('Bitte wähle ein Datum und eine Uhrzeit.');
        return;
    }

    const selectedDateTime = new Date(`${date}T${time}`);
    fetchPlanForDate(selectedDateTime).then(xmlText => {
        if (!xmlText) {
            showMessageModal('Kein Plan für das ausgewählte Datum verfügbar.');
            return;
        }

        const roomLessons = parseRoomDetails(xmlText, roomNumber, selectedDateTime);
        displayRoomDetails(roomNumber, roomLessons);
    }).catch(error => {
        console.error('Fehler beim Laden der Raumdetails:', error);
        showMessageModal('Fehler beim Laden der Raumdetails.');
    });
}

function parseRoomDetails(xmlText, roomNumber, selectedTime) {
    const parser = new DOMParser();
    const xmlDoc = parser.parseFromString(xmlText, 'text/xml');
    const classes = xmlDoc.querySelectorAll('Kl');
    const lessons = [];

    classes.forEach(cls => {
        const className = cls.querySelector('Kurz')?.textContent;
        const stunden = cls.querySelectorAll('Std');

        stunden.forEach(std => {
            const beginn = std.querySelector('Beginn')?.textContent;
            const ende = std.querySelector('Ende')?.textContent;
            const room = std.querySelector('Ra')?.textContent;
            const st = std.querySelector('St')?.textContent;
            const fa = std.querySelector('Fa')?.textContent;
            const le = std.querySelector('Le')?.textContent;
            const regel = std.querySelector('If')?.textContent;

            if (room && beginn && ende) {
                // Clean room name
                let editRoom = room.replace(/H[123]|E/g, '');
                if (/^\d+$/.test(editRoom) && parseInt(editRoom) === roomNumber) {

                    // Create Date objects for comparison
                    const lessonStart = new Date(`${selectedTime.toDateString()} ${beginn}`);
                    const lessonEnd = new Date(`${selectedTime.toDateString()} ${ende}`);

                    // Check if the selected time falls within the lesson's duration
                    if (selectedTime >= lessonStart && selectedTime < lessonEnd) {
                        lessons.push({
                            klasse: className,
                            stunde: parseInt(st),
                            fach: fa,
                            lehrer: le,
                            beginn: beginn,
                            ende: ende,
                            regel: regel || ''
                        });
                    }
                }
            }
        });
    });

    lessons.sort((a, b) => a.stunde - b.stunde);
    return lessons;
}

function displayRoomDetails(roomNumber, lessons) {
    document.getElementById('room-details-title').textContent = `${_('spaceDetails')} ${roomNumber}`;
    const detailsContent = document.getElementById('room-details-content');

    if (lessons.length === 0) {
        detailsContent.innerHTML = `<p>${_('noLessonInSpaceAtTime')}</p>`;
    } else {
        detailsContent.innerHTML = `<p>${_('detailsWillTakePlace')}</p>`;
        lessons.forEach(lesson => {
            const lessonItem = document.createElement('div');
            lessonItem.className = 'class-item';
            lessonItem.innerHTML = `
                <strong>${_('lessonNum')} ${lesson.stunde}: ${lesson.fach}</strong>
                <div>${_('classCol')}: ${lesson.klasse}</div>
                <div>${_('teacherCol')}: ${lesson.lehrer}</div>
                <div>${_('timeColon')} ${lesson.beginn} - ${lesson.ende}</div>
                ${lesson.regel ? `<div>${_('infoColon')} ${lesson.regel}</div>` : ''}
            `;
            detailsContent.appendChild(lessonItem);
        });

    }

    document.getElementById('room-details-modal').style.display = 'block';

}

function updateTexts() {
    document.documentElement.lang = currentLang;
    // Update input placeholders
    document.getElementById('schoolnumber').placeholder = _('schoolNumber');
    document.getElementById('username').placeholder = _('username');
    document.getElementById('password').placeholder = _('password');
    document.getElementById('customUrl').placeholder = _('customUrlOptional');

    // Update buttons
    const loadClassesBtn = document.querySelector('button[onclick*="loadClasses"]');
    if (loadClassesBtn) loadClassesBtn.textContent = _('loadClasses');
    const customUrlBtn = document.querySelector('button[onclick*="toggleCustomUrl"]');
    if (customUrlBtn) customUrlBtn.textContent = _('useCustomUrl');

    // Update h2
    const vplanH2 = document.querySelector('#login-form h2');
    if (vplanH2) vplanH2.textContent = _('vplanCredentials');
    const classH2 = document.querySelector('#class-list-container h2');
    if (classH2) classH2.textContent = _('selectClass');
    const teacherH2 = document.querySelector('#tab-teacher h2');
    if (teacherH2) teacherH2.textContent = _('teacherManagement');
    const teacherP = document.querySelector('#tab-teacher p');
    if (teacherP) teacherP.textContent = _('manageTeacherAbbreviations');
    const freeroomsH2 = document.querySelector('#tab-freerooms h2');
    if (freeroomsH2) freeroomsH2.textContent = _('rooms');
    const freeroomsP = document.querySelector('#tab-freerooms p');
    if (freeroomsP) freeroomsP.textContent = _('selectDayTimeFindFreeRooms');
    const searchBtn = document.querySelector('#tab-freerooms button[onclick*="findFreeRooms"]');
    if (searchBtn) searchBtn.textContent = _('search');
    const settingsH2 = document.querySelector('#tab-settings h2');
    if (settingsH2) settingsH2.textContent = _('settings');
    const changeAccessBtn = document.querySelector('#tab-settings button[onclick*="showSettings"]');
    if (changeAccessBtn) changeAccessBtn.textContent = _('changeAccessData');
    const showAnalyticsBtn = document.querySelector('#tab-settings button[onclick*="showAnalytics"]');
    if (showAnalyticsBtn) showAnalyticsBtn.textContent = _('showAnalytics');
    const deleteDataBtn = document.querySelector('#tab-settings button[onclick*="clearData"]');
    if (deleteDataBtn) deleteDataBtn.textContent = _('deleteData');

    // Nav items
    const navItems = document.querySelectorAll('.bottom-nav .nav-item div:last-child');
    navItems[0].textContent = _('tabVPlan');
    navItems[1].textContent = _('tabTeachers');
    navItems[2].textContent = _('tabRooms');
    navItems[3].textContent = _('tabSettings');

    // Modals
    const infoH2 = document.querySelector('#info-modal h2');
    if (infoH2) infoH2.textContent = _('appInfo');
    const infoP = document.querySelector('#info-modal p');
    if (infoP) infoP.textContent = _('substituteOrganizer');
    const bugLink = document.querySelector('#info-modal .class-item:nth-child(4) a');
    if (bugLink) bugLink.textContent = _('reportBug');
    const reqLink = document.querySelector('#info-modal .class-item:nth-child(5) a');
    if (reqLink) reqLink.textContent = _('requestFeature');
    const changeLink = document.querySelector('#info-modal .class-item:nth-child(6) a');
    if (changeLink) changeLink.textContent = _('changelog');
    const closeBtn = document.querySelector('#info-modal button');
    if (closeBtn) closeBtn.textContent = _('close');
    const okBtn = document.querySelector('#message-modal button');
    if (okBtn) okBtn.textContent = _('ok');
    const yesBtn = document.querySelector('#confirm-modal button:first-of-type');
    if (yesBtn) yesBtn.textContent = _('yes');
    const noBtn = document.querySelector('#confirm-modal button:last-of-type');
    if (noBtn) noBtn.textContent = _('no');

    // Language selector
    const langSelect = document.getElementById('language-select');
    if (langSelect) {
        langSelect.value = currentLang;
    }

    // Teacher search placeholder
    const searchInput = document.getElementById('teacher-search');
    if (searchInput) searchInput.placeholder = _('searchTeacher');
}

function showWeek() {
    const week = weekNumber(currentDate) % 2 !== 0 ? 'A' : 'B';
    document.getElementById('week-text').textContent = week;
    document.getElementById('week-modal').style.display = 'block';
}

function changeLanguage(lang) {
    currentLang = lang;
    localStorage.setItem('language', lang);
    loadTranslations();
}

// --- Course Selection Functions ---

function getHiddenCourses() {
    const hidden = localStorage.getItem('hiddenSubjects');
    return hidden ? JSON.parse(hidden) : [];
}

function addHiddenCourse(course) {
    if (course === '---') return;
    const hidden = getHiddenCourses();
    if (!hidden.includes(course)) {
        hidden.push(course);
        localStorage.setItem('hiddenSubjects', JSON.stringify(hidden));
    }
}

function removeHiddenCourse(course) {
    const hidden = getHiddenCourses();
    const newHidden = hidden.filter(c => c !== course);
    localStorage.setItem('hiddenSubjects', JSON.stringify(newHidden));
}

function parseCourses(xmlText, className) {
    const parser = new DOMParser();
    const xmlDoc = parser.parseFromString(xmlText, 'text/xml');
    const classes = xmlDoc.querySelectorAll('Kl');
    const courses = [];
    const hiddenCourses = getHiddenCourses();

    for (let i = 0; i < classes.length; i++) {
        const kurz = classes[i].querySelector('Kurz');
        if (kurz && kurz.textContent === className) {
            const kurseElement = classes[i].querySelector('Kurse');
            if (kurseElement) {
                const kuElements = kurseElement.querySelectorAll('Ku');
                kuElements.forEach(ku => {
                    const kkz = ku.querySelector('KKz');
                    if (kkz) {
                        const courseName = kkz.textContent;
                        const teacher = kkz.attributes.length > 0 ? kkz.attributes[0].value : '';
                        if (courseName && courseName !== '---') {
                            // Avoid duplicates
                            const exists = courses.some(c => c.course === courseName);
                            if (!exists) {
                                courses.push({
                                    course: courseName,
                                    teacher: teacher,
                                    show: !hiddenCourses.includes(courseName)
                                });
                            }
                        }
                    }
                });
            }
            break;
        }
    }

    // Sort courses alphabetically
    courses.sort((a, b) => a.course.localeCompare(b.course));
    return courses;
}

async function showCoursesModal() {
    const favoriteClass = localStorage.getItem('favoriteClass');
    if (!favoriteClass) {
        showMessageModal(currentLang === 'de' ? 'Bitte wähle zuerst eine Klasse aus.' : 'Please select a class first.');
        return;
    }

    // Try to get courses from cached XML or fetch new data
    let xmlText = cachedXmlData;
    if (!xmlText) {
        try {
            xmlText = await fetchPlanForDate(currentDate);
        } catch (error) {
            console.error('Error fetching data for courses:', error);
            showMessageModal(currentLang === 'de' ? 'Fehler beim Laden der Kurse.' : 'Error loading courses.');
            return;
        }
    }

    if (!xmlText) {
        showMessageModal(currentLang === 'de' ? 'Keine Daten verfügbar.' : 'No data available.');
        return;
    }

    cachedCourses = parseCourses(xmlText, favoriteClass);
    
    const coursesTitle = document.getElementById('courses-modal-title');
    coursesTitle.textContent = currentLang === 'de' ? 'Kurse' : 'Courses';
    
    displayCourses();
    document.getElementById('courses-modal').style.display = 'block';
}

function displayCourses() {
    const coursesList = document.getElementById('courses-list');
    coursesList.innerHTML = '';

    if (cachedCourses.length === 0) {
        coursesList.innerHTML = `<p style="text-align: center; color: #888;">${currentLang === 'de' ? 'Keine Kurse verfügbar' : 'No courses available'}</p>`;
        return;
    }

    cachedCourses.forEach((course, index) => {
        const courseItem = document.createElement('div');
        courseItem.className = `course-item ${course.show ? 'visible' : 'hidden'}`;
        courseItem.onclick = () => toggleCourse(index);
        courseItem.innerHTML = `
            <div class="course-info">
                <span class="course-name">${course.course}</span>
                <span class="course-teacher">(${course.teacher})</span>
            </div>
            <div class="course-icon">
                <span class="material-icons">${course.show ? 'visibility' : 'visibility_off'}</span>
            </div>
        `;
        coursesList.appendChild(courseItem);
    });
}

function toggleCourse(index) {
    const course = cachedCourses[index];
    course.show = !course.show;
    
    if (course.show) {
        removeHiddenCourse(course.course);
    } else {
        addHiddenCourse(course.course);
    }
    
    displayCourses();
    refreshCurrentView();
}

function showAllCourses() {
    cachedCourses.forEach(course => {
        course.show = true;
        removeHiddenCourse(course.course);
    });
    displayCourses();
    refreshCurrentView();
}

function hideAllCourses() {
    cachedCourses.forEach(course => {
        course.show = false;
        addHiddenCourse(course.course);
    });
    displayCourses();
    refreshCurrentView();
}

function closeCoursesModal() {
    document.getElementById('courses-modal').style.display = 'none';
}

function refreshCurrentView() {
    if (currentView.type === 'class' && currentView.name) {
        loadClassDetails(currentView.name, true);
    }
}

// Filter lessons based on hidden courses
function filterLessonsByVisibility(lessons) {
    const hiddenCourses = getHiddenCourses();
    return lessons.filter(lesson => {
        // Check if the lesson's subject (fach) is in the hidden list
        // The app uses course field from Ku2, but lessons use 'fach'
        return !hiddenCourses.includes(lesson.fach);
    });
}