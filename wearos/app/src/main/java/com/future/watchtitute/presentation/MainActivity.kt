package com.future.watchtitute.presentation

import android.app.RemoteInput
import android.content.Intent
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.wear.compose.material.*
import com.future.watchtitute.data.datastore.UserDataStore
import androidx.wear.input.RemoteInputIntentHelper
import com.future.watchtitute.data.VPlanApi
import com.future.watchtitute.data.VPlanEntry
import com.future.watchtitute.presentation.theme.WatchtituteTheme
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import java.util.Base64

class MainActivity : ComponentActivity() {
    private lateinit var userDataStore: UserDataStore
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        userDataStore = UserDataStore(applicationContext)
        setContent {
            WatchtituteTheme {
                VPlanApp(userDataStore = userDataStore)
            }
        }
    }
}

@Composable
fun VPlanApp(
    userDataStore: UserDataStore,
    viewModel: VPlanViewModel = viewModel(
        factory = VPlanViewModelFactory(userDataStore)
    )
) {
    val vplanState by viewModel.vplanState.collectAsState()

    // Check for saved credentials on app start
    LaunchedEffect(Unit) {
        viewModel.checkSavedCredentials()
    }

    when (vplanState.loginStep) {
        LoginStep.Login -> LoginScreen(
            onLoginClick = { school, user, pass ->
                viewModel.login(school, user, pass)
            },
            isLoading = vplanState.isLoading,
            errorMessage = vplanState.errorMessage
        )
        LoginStep.SelectClass -> ClassSelectionScreen(
            classes = vplanState.classes,
            onClassSelected = { className ->
                viewModel.onClassSelected(className)
            },
            isLoading = vplanState.isLoading
        )
        LoginStep.VPlan -> VPlanScreen(
            entries = vplanState.entries,
            currentClass = vplanState.currentClass,
            onLogout = { viewModel.logout() },
            onSetDefaultClass = { viewModel.setDefaultClass(it) }
        )
    }
}

@Composable
fun LoginScreen(
    onLoginClick: (String, String, String) -> Unit,
    isLoading: Boolean,
    errorMessage: String?
) {
    var schoolNumber by remember { mutableStateOf("") }
    var username by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }

    val schoolNumberLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) {
        it.data?.let { data ->
            val results = RemoteInput.getResultsFromIntent(data)
            results?.getCharSequence("school_number")?.let {
                schoolNumber = it.toString()
            }
        }
    }

    val usernameLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) {
        it.data?.let { data ->
            val results = RemoteInput.getResultsFromIntent(data)
            results?.getCharSequence("username")?.let {
                username = it.toString()
            }
        }
    }

    val passwordLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) {
        it.data?.let { data ->
            val results = RemoteInput.getResultsFromIntent(data)
            results?.getCharSequence("password")?.let {
                password = it.toString()
            }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        OutlinedChip(
            onClick = {
                val intent = RemoteInputIntentHelper.createActionRemoteInputIntent()
                val remoteInputs: List<RemoteInput> = listOf(
                    RemoteInput.Builder("school_number")
                        .setLabel("School Number")
                        .build()
                )
                RemoteInputIntentHelper.putRemoteInputsExtra(intent, remoteInputs)
                schoolNumberLauncher.launch(intent)
            },
            label = { Text(if (schoolNumber.isEmpty()) "School Number" else schoolNumber, color = Color.Black) },
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(modifier = Modifier.height(8.dp))
        OutlinedChip(
            onClick = {
                val intent = RemoteInputIntentHelper.createActionRemoteInputIntent()
                val remoteInputs: List<RemoteInput> = listOf(
                    RemoteInput.Builder("username")
                        .setLabel("Username")
                        .build()
                )
                RemoteInputIntentHelper.putRemoteInputsExtra(intent, remoteInputs)
                usernameLauncher.launch(intent)
            },
            label = { Text(if (username.isEmpty()) "Username" else username, color = Color.Black) },
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(modifier = Modifier.height(8.dp))
        OutlinedChip(
            onClick = {
                val intent = RemoteInputIntentHelper.createActionRemoteInputIntent()
                val remoteInputs: List<RemoteInput> = listOf(
                    RemoteInput.Builder("password")
                        .setLabel("Password")
                        .build()
                )
                RemoteInputIntentHelper.putRemoteInputsExtra(intent, remoteInputs)
                passwordLauncher.launch(intent)
            },
            label = { Text(if (password.isEmpty()) "Password" else "********", color = Color.Black) },
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(modifier = Modifier.height(16.dp))
        Button(
            onClick = {
                onLoginClick(schoolNumber, username, password)
            },
            enabled = !isLoading
        ) {
            if (isLoading) {
                CircularProgressIndicator(modifier = Modifier.size(24.dp))
            } else {
                Text("Login")
            }
        }
        errorMessage?.let {
            Spacer(modifier = Modifier.height(8.dp))
            Text(it, color = MaterialTheme.colors.error)
        }
    }
}

@Composable
fun ClassSelectionScreen(
    classes: List<String>,
    onClassSelected: (String) -> Unit,
    isLoading: Boolean
) {
    val state = rememberPickerState(initialNumberOfOptions = classes.size)
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("Select Class")
        Spacer(modifier = Modifier.height(8.dp))
        Picker(
            modifier = Modifier.weight(1f),
            state = state,
            contentDescription = "Select Class",
        ) {
            Text(classes[it], color = Color.Black)
        }
        Spacer(modifier = Modifier.height(16.dp))
        Button(
            onClick = { onClassSelected(classes[state.selectedOption]) },
            enabled = !isLoading && classes.isNotEmpty(),
            modifier = Modifier.fillMaxWidth()
        ) {
            if (isLoading) {
                CircularProgressIndicator(modifier = Modifier.size(24.dp))
            } else {
                Text("Show Plan", textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
            }
        }
    }
}

@Composable
fun VPlanScreen(
    entries: List<VPlanEntry>,
    currentClass: String,
    onLogout: () -> Unit,
    onSetDefaultClass: (String) -> Unit
) {
    val listState = rememberScalingLazyListState()

    // Scrolls up if the list is not empty
    LaunchedEffect(entries) {
        if (entries.isNotEmpty()) {
            listState.scrollToItem(index = 0, scrollOffset = 0)
        }
    }

    Scaffold(
        vignette = { Vignette(vignettePosition = VignettePosition.TopAndBottom) },
        positionIndicator = { PositionIndicator(scalingLazyListState = listState) }
    ) {
        ScalingLazyColumn(
            modifier = Modifier.fillMaxSize(),
            state = listState
        ) {
            items(entries) { entry ->
                Card(onClick = {}) {
                    Column(modifier = Modifier.padding(8.dp)) {
                        Text("Lesson: ${entry.count ?: ""}", style = MaterialTheme.typography.title3)
                        Text("Subject: ${entry.lesson ?: ""}", style = MaterialTheme.typography.body1)
                        Text("Teacher: ${entry.teacher ?: ""}", style = MaterialTheme.typography.body2)
                        Text("Room: ${entry.place ?: ""}", style = MaterialTheme.typography.body2)
                        if (entry.info?.isNotEmpty() == true) {
                            Text("Info: ${entry.info}", style = MaterialTheme.typography.body2)
                        }
                    }
                }
            }
            item {
                Button(onClick = onLogout, modifier = Modifier.fillMaxWidth()) {
                    Text("Logout")
                }
            }
            if (currentClass.isNotEmpty()) {
                item {
                    Spacer(modifier = Modifier.height(8.dp))
                    Button(
                        onClick = { onSetDefaultClass(currentClass) },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Set as Default")
                    }
                }
            }
        }
    }
}

enum class LoginStep {
    Login,
    SelectClass,
    VPlan
}

class VPlanViewModel(private val userDataStore: UserDataStore) : ViewModel() {
    private val _vplanState = MutableStateFlow(VPlanState())
    val vplanState = _vplanState

    private val api = VPlanApi()

    fun checkSavedCredentials() {
        viewModelScope.launch {
            try {
                // Get current values from flows
                val username = userDataStore.usernameFlow.first() as? String
                val password = userDataStore.passwordFlow.first() as? String
                val schoolNumber = userDataStore.schoolNumberFlow.first() as? String
                val defaultClass = userDataStore.defaultClassFlow.first() as? String

                if (username?.isNotEmpty() == true && password?.isNotEmpty() == true && schoolNumber?.isNotEmpty() == true) {
                    // Attempt automatic login with saved credentials
                    _vplanState.value = _vplanState.value.copy(isLoading = true, errorMessage = null)

                    Log.d("VPlanViewModel", "Attempting auto-login with saved credentials")
                    val authString = "$username:$password"
                    val auth = Base64.getEncoder().encodeToString(authString.toByteArray())
                    val classes = api.getClasses(schoolNumber, auth)

                    Log.d("VPlanViewModel", "Auto-login successful, found ${classes.size} classes")

                    if (classes.isNotEmpty()) {
                        // Check if we have a default class and it exists in the available classes
                        if (defaultClass?.isNotEmpty() == true && classes.contains(defaultClass)) {
                            Log.d("VPlanViewModel", "Found default class: $defaultClass, loading plan automatically")
                            // Load the default class plan directly
                            try {
                                val entries = api.getVPlan(defaultClass)
                                _vplanState.value = _vplanState.value.copy(
                                    loginStep = LoginStep.VPlan,
                                    entries = entries,
                                    isLoading = false
                                )
                            } catch (e: Exception) {
                                Log.e("VPlanViewModel", "Failed to load default class plan", e)
                                // Fall back to class selection
                                _vplanState.value = _vplanState.value.copy(
                                    loginStep = LoginStep.SelectClass,
                                    classes = classes,
                                    isLoading = false
                                )
                            }
                        } else {
                            // No default class or it doesn't exist, show class selection
                            _vplanState.value = _vplanState.value.copy(
                                loginStep = LoginStep.SelectClass,
                                classes = classes,
                                isLoading = false
                            )
                        }
                    } else {
                        // No classes found, clear saved credentials and show login
                        userDataStore.saveCredentials("", "", "")
                        _vplanState.value = _vplanState.value.copy(
                            isLoading = false,
                            errorMessage = "No classes found for saved credentials."
                        )
                    }
                } else {
                    // No saved credentials, stay on login screen
                    Log.d("VPlanViewModel", "No saved credentials found")
                }
            } catch (e: Exception) {
                Log.e("VPlanViewModel", "Auto-login failed", e)
                // Clear potentially corrupted credentials
                userDataStore.saveCredentials("", "", "")
                _vplanState.value = _vplanState.value.copy(
                    isLoading = false,
                    errorMessage = "Auto-login failed. Please login manually."
                )
            }
        }
    }

    fun login(schoolNumber: String, user: String, pass: String) {
        viewModelScope.launch {
            _vplanState.value = _vplanState.value.copy(isLoading = true, errorMessage = null)
            try {
                Log.d("VPlanViewModel", "Logging in with schoolNumber: $schoolNumber")
                val authString = "$user:$pass"
                val auth = Base64.getEncoder().encodeToString(authString.toByteArray())
                val classes = api.getClasses(schoolNumber, auth)
                Log.d("VPlanViewModel", "Found ${classes.size} classes")
                if (classes.isNotEmpty()) {
                    userDataStore.saveCredentials(user, pass, schoolNumber)
                    _vplanState.value = _vplanState.value.copy(
                        loginStep = LoginStep.SelectClass,
                        classes = classes,
                        isLoading = false
                    )
                } else {
                    _vplanState.value = _vplanState.value.copy(
                        isLoading = false,
                        errorMessage = "No classes found for this user."
                    )
                }
            } catch (e: Exception) {
                Log.e("VPlanViewModel", "Login failed", e)
                _vplanState.value = _vplanState.value.copy(
                    isLoading = false,
                    errorMessage = "Login failed. Please check your credentials."
                )
            }
        }
    }

    fun onClassSelected(className: String) {
        viewModelScope.launch {
            _vplanState.value = _vplanState.value.copy(isLoading = true, currentClass = className)
            try {
                val entries = api.getVPlan(className)
                _vplanState.value = _vplanState.value.copy(
                    loginStep = LoginStep.VPlan,
                    entries = entries,
                    isLoading = false
                )
            } catch (e: Exception) {
                // Handle error
                _vplanState.value = _vplanState.value.copy(isLoading = false)
            }
        }
    }

    fun logout() {
        viewModelScope.launch {
            userDataStore.saveCredentials("", "", "")
            _vplanState.value = VPlanState()
        }
    }

    fun setDefaultClass(className: String) {
        viewModelScope.launch {
            userDataStore.saveDefaultClass(className)
        }
    }
}

data class VPlanState(
    val loginStep: LoginStep = LoginStep.Login,
    val entries: List<VPlanEntry> = emptyList(),
    val isLoading: Boolean = false,
    val classes: List<String> = emptyList(),
    val currentClass: String = "",
    val errorMessage: String? = null
)

class VPlanViewModelFactory(private val userDataStore: UserDataStore) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(VPlanViewModel::class.java)) {
            @Suppress("UNCHECKED_CAST")
            return VPlanViewModel(userDataStore) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}
