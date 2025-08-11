package com.future.watchtitute.data.datastore

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "user_prefs")

class UserDataStore(context: Context) {

    private val dataStore = context.dataStore

    companion object {
        val USERNAME_KEY = stringPreferencesKey("username")
        val PASSWORD_KEY = stringPreferencesKey("password")
        val SCHOOL_NUMBER_KEY = stringPreferencesKey("school_number")
    }

    suspend fun saveCredentials(username: String, password: String, schoolNumber: String) {
        dataStore.edit { preferences ->
            preferences[USERNAME_KEY] = username
            preferences[PASSWORD_KEY] = password
            preferences[SCHOOL_NUMBER_KEY] = schoolNumber
        }
    }

    val usernameFlow: Flow<String?> = dataStore.data.map { preferences ->
        preferences[USERNAME_KEY]
    }

    val passwordFlow: Flow<String?> = dataStore.data.map { preferences ->
        preferences[PASSWORD_KEY]
    }

    val schoolNumberFlow: Flow<String?> = dataStore.data.map { preferences ->
        preferences[SCHOOL_NUMBER_KEY]
    }
}
