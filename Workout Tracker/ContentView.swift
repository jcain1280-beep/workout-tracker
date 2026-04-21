import SwiftUI
import Foundation
import UIKit
import Combine
import GoogleSignIn
import GoogleSignInSwift
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var store = WorkoutStore()
    @StateObject private var calendarService = GoogleCalendarService()

    @State private var selectedTab: AppTab = .home
    @State private var selectedCategoryID: UUID?
    @State private var showingHomeAddWorkout = false
    @Environment(\.scenePhase) private var scenePhase

    enum AppTab {
        case home, workout, history, settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(
                selectedTab: $selectedTab,
                selectedCategoryID: $selectedCategoryID,
                showingAddWorkout: $showingHomeAddWorkout
            )
            .environmentObject(store)
            .environmentObject(calendarService)
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(AppTab.home)

            LogWorkoutView(
                selectedCategoryID: $selectedCategoryID,
                selectedTab: $selectedTab
            )
            .environmentObject(store)
            .environmentObject(calendarService)
            .tabItem { Label("Workout", systemImage: "plus.circle.fill") }
            .tag(AppTab.workout)

            HistoryView()
                .environmentObject(store)
                .environmentObject(calendarService)
                .tabItem { Label("History", systemImage: "clock.fill") }
                .tag(AppTab.history)

            SettingsView()
                .environmentObject(store)
                .environmentObject(calendarService)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingHomeAddWorkout) {
            AddCategorySheet()
                .environmentObject(store)
        }
        .task {
            if selectedCategoryID == nil {
                selectedCategoryID = store.homeCategories().first?.id ?? store.categories.first?.id
            }
            await autoSyncIfPossible()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await autoSyncIfPossible() }
            }
        }
    }

    private func autoSyncIfPossible() async {
        guard calendarService.isSignedIn else { return }

        do {
            let imported = try await calendarService.importWorkoutsFromCalendar(range: store.calendarSyncRange)
            store.reconcileWithCalendar(imported)
        } catch {
            // silent
        }
    }
}

// MARK: - Models

enum CalendarSyncRange: String, Codable, CaseIterable, Identifiable {
    case days30
    case days90
    case months6
    case year1
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .days30: return "Last 30 Days"
        case .days90: return "Last 90 Days"
        case .months6: return "Last 6 Months"
        case .year1: return "Last 1 Year"
        case .all: return "All Available"
        }
    }

    var dateFrom: Date? {
        let cal = Calendar.current
        let now = Date()

        switch self {
        case .days30: return cal.date(byAdding: .day, value: -30, to: now)
        case .days90: return cal.date(byAdding: .day, value: -90, to: now)
        case .months6: return cal.date(byAdding: .month, value: -6, to: now)
        case .year1: return cal.date(byAdding: .year, value: -1, to: now)
        case .all: return nil
        }
    }
}

enum TileStyle: String, Codable, CaseIterable, Identifiable {
    case purplePink
    case orangeRed
    case greenMint
    case blueCyan
    case indigoTeal
    case grayDark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .purplePink: return "Purple / Pink"
        case .orangeRed: return "Orange / Red"
        case .greenMint: return "Green / Mint"
        case .blueCyan: return "Blue / Cyan"
        case .indigoTeal: return "Indigo / Teal"
        case .grayDark: return "Gray / Dark"
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .purplePink:
            return LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .orangeRed:
            return LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .greenMint:
            return LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .blueCyan:
            return LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .indigoTeal:
            return LinearGradient(colors: [.indigo, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .grayDark:
            return LinearGradient(colors: [.gray, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

enum CategorySymbol: String, Codable, CaseIterable, Identifiable {
    case dumbbell = "dumbbell.fill"
    case run = "figure.run"
    case walk = "figure.walk"
    case swim = "figure.pool.swim"
    case golf = "figure.golf"
    case jump = "figure.jumprope"
    case kayak = "figure.open.water.swim"
    case ski = "figure.skiing.downhill"
    case skate = "figure.skating"
    case basketball = "figure.basketball"
    case football = "figure.american.football"
    case soccer = "figure.soccer"
    case flame = "flame.fill"
    case bolt = "bolt.fill"
    case heart = "heart.fill"
    case star = "star.fill"
    case trophy = "trophy.fill"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dumbbell: return "Dumbbell"
        case .run: return "Run"
        case .walk: return "Walk"
        case .swim: return "Swim"
        case .golf: return "Golf"
        case .jump: return "Jump Rope"
        case .kayak: return "Kayaking"
        case .ski: return "Skiing"
        case .skate: return "Skating"
        case .basketball: return "Basketball"
        case .football: return "Football"
        case .soccer: return "Soccer"
        case .flame: return "Flame"
        case .bolt: return "Bolt"
        case .heart: return "Heart"
        case .star: return "Star"
        case .trophy: return "Trophy"
        }
    }
}

struct WorkoutCategory: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var symbolRaw: String
    var styleRaw: String
    var isVisibleOnHome: Bool
    var homeOrder: Int

    init(
        id: UUID = UUID(),
        name: String,
        symbolRaw: String,
        styleRaw: String,
        isVisibleOnHome: Bool = true,
        homeOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.symbolRaw = symbolRaw
        self.styleRaw = styleRaw
        self.isVisibleOnHome = isVisibleOnHome
        self.homeOrder = homeOrder
    }

    var symbol: String { symbolRaw }

    var tileStyle: TileStyle {
        TileStyle(rawValue: styleRaw) ?? .indigoTeal
    }

    var gradient: LinearGradient {
        tileStyle.gradient
    }

    static let defaults: [WorkoutCategory] = [
        .init(name: "Weightlifting", symbolRaw: CategorySymbol.dumbbell.rawValue, styleRaw: TileStyle.purplePink.rawValue, isVisibleOnHome: true, homeOrder: 0),
        .init(name: "Running", symbolRaw: CategorySymbol.run.rawValue, styleRaw: TileStyle.orangeRed.rawValue, isVisibleOnHome: true, homeOrder: 1),
        .init(name: "Walking", symbolRaw: CategorySymbol.walk.rawValue, styleRaw: TileStyle.greenMint.rawValue, isVisibleOnHome: true, homeOrder: 2),
        .init(name: "Swimming", symbolRaw: CategorySymbol.swim.rawValue, styleRaw: TileStyle.blueCyan.rawValue, isVisibleOnHome: true, homeOrder: 3),
        .init(name: "Soccer", symbolRaw: CategorySymbol.soccer.rawValue, styleRaw: TileStyle.indigoTeal.rawValue, isVisibleOnHome: true, homeOrder: 4),
        .init(name: "Golf", symbolRaw: CategorySymbol.golf.rawValue, styleRaw: TileStyle.grayDark.rawValue, isVisibleOnHome: true, homeOrder: 5)
    ]
}

struct WorkoutType: Codable, Identifiable, Hashable {
    let id: UUID
    var categoryID: UUID
    var name: String

    init(id: UUID = UUID(), categoryID: UUID, name: String) {
        self.id = id
        self.categoryID = categoryID
        self.name = name
    }

    static func defaults(categories: [WorkoutCategory]) -> [WorkoutType] {
        func id(named: String) -> UUID {
            categories.first(where: { $0.name == named })?.id ?? UUID()
        }

        return [
            .init(categoryID: id(named: "Weightlifting"), name: "Chest"),
            .init(categoryID: id(named: "Weightlifting"), name: "Triceps"),
            .init(categoryID: id(named: "Weightlifting"), name: "Legs"),
            .init(categoryID: id(named: "Weightlifting"), name: "Shoulders"),
            .init(categoryID: id(named: "Weightlifting"), name: "Back"),
            .init(categoryID: id(named: "Weightlifting"), name: "Biceps"),
            .init(categoryID: id(named: "Running"), name: "Running"),
            .init(categoryID: id(named: "Walking"), name: "Walking"),
            .init(categoryID: id(named: "Swimming"), name: "Swimming"),
            .init(categoryID: id(named: "Soccer"), name: "Soccer"),
            .init(categoryID: id(named: "Golf"), name: "Golf")
        ]
    }
}

struct LoggedWorkout: Codable, Identifiable, Hashable {
    let id: UUID
    var googleEventID: String?
    var typeID: UUID?
    var categoryID: UUID?
    var workoutName: String
    var categoryName: String
    var minutes: Int
    var notes: String
    var date: Date
    var syncedToGoogleCalendar: Bool

    init(
        id: UUID = UUID(),
        googleEventID: String? = nil,
        typeID: UUID? = nil,
        categoryID: UUID? = nil,
        workoutName: String,
        categoryName: String,
        minutes: Int,
        notes: String = "",
        date: Date = .now,
        syncedToGoogleCalendar: Bool = false
    ) {
        self.id = id
        self.googleEventID = googleEventID
        self.typeID = typeID
        self.categoryID = categoryID
        self.workoutName = workoutName
        self.categoryName = categoryName
        self.minutes = minutes
        self.notes = notes
        self.date = date
        self.syncedToGoogleCalendar = syncedToGoogleCalendar
    }
}

// MARK: - Store

@MainActor
final class WorkoutStore: ObservableObject {
    @Published var categories: [WorkoutCategory] = []
    @Published var workoutTypes: [WorkoutType] = []
    @Published var loggedWorkouts: [LoggedWorkout] = []
    @Published var syncToGoogleCalendar = true
    @Published var calendarSyncRange: CalendarSyncRange = .year1
    @Published var homeBannerMessage: String?

    private let categoriesKey = "musclemetrics.categories"
    private let workoutTypesKey = "musclemetrics.workout.types"
    private let loggedWorkoutsKey = "musclemetrics.workout.logs"
    private let syncKey = "musclemetrics.calendar.sync.enabled"
    private let syncRangeKey = "musclemetrics.calendar.sync.range"

    init() {
        load()
    }

    func showHomeBanner(_ message: String, duration: UInt64 = 2_000_000_000) {
        homeBannerMessage = message

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: duration)
            if self.homeBannerMessage == message {
                self.homeBannerMessage = nil
            }
        }
    }

    func moveHomeCategory(from draggedID: UUID, to targetID: UUID) {
        var visible = homeCategories()

        guard let fromIndex = visible.firstIndex(where: { $0.id == draggedID }),
              let toIndex = visible.firstIndex(where: { $0.id == targetID }),
              fromIndex != toIndex else { return }

        let moved = visible.remove(at: fromIndex)
        visible.insert(moved, at: toIndex)

        for (index, item) in visible.enumerated() {
            if let originalIndex = categories.firstIndex(where: { $0.id == item.id }) {
                categories[originalIndex].homeOrder = index
            }
        }

        saveCategories()
    }

    func load() {
        let decoder = JSONDecoder()

        if let data = UserDefaults.standard.data(forKey: categoriesKey),
           let decoded = try? decoder.decode([WorkoutCategory].self, from: data) {
            categories = decoded
        } else {
            categories = WorkoutCategory.defaults
            saveCategories()
        }

        if let data = UserDefaults.standard.data(forKey: workoutTypesKey),
           let decoded = try? decoder.decode([WorkoutType].self, from: data) {
            workoutTypes = decoded
        } else {
            workoutTypes = WorkoutType.defaults(categories: categories)
            saveWorkoutTypes()
        }

        if let data = UserDefaults.standard.data(forKey: loggedWorkoutsKey),
           let decoded = try? decoder.decode([LoggedWorkout].self, from: data) {
            loggedWorkouts = decoded.sorted { $0.date > $1.date }
        }

        if UserDefaults.standard.object(forKey: syncKey) == nil {
            syncToGoogleCalendar = true
        } else {
            syncToGoogleCalendar = UserDefaults.standard.bool(forKey: syncKey)
        }

        if let raw = UserDefaults.standard.string(forKey: syncRangeKey),
           let range = CalendarSyncRange(rawValue: raw) {
            calendarSyncRange = range
        }
    }

    func categoriesSorted() -> [WorkoutCategory] {
        categories.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func homeCategories() -> [WorkoutCategory] {
        categories
            .filter { $0.isVisibleOnHome }
            .sorted { $0.homeOrder < $1.homeOrder }
    }

    func hiddenCategories() -> [WorkoutCategory] {
        categories
            .filter { !$0.isVisibleOnHome }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func category(by id: UUID?) -> WorkoutCategory? {
        guard let id else { return nil }
        return categories.first(where: { $0.id == id })
    }

    func category(named name: String) -> WorkoutCategory? {
        categories.first(where: { $0.name.lowercased() == name.lowercased() })
    }

    func workouts(for categoryID: UUID?) -> [WorkoutType] {
        guard let categoryID else { return [] }
        return workoutTypes
            .filter { $0.categoryID == categoryID }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func groupedWorkoutTypes() -> [(category: WorkoutCategory, items: [WorkoutType])] {
        categoriesSorted().map { category in
            (category, workouts(for: category.id))
        }
    }

    private var sundayStartCalendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 1
        return calendar
    }

    func workoutsForThisWeek() -> [LoggedWorkout] {
        let calendar = sundayStartCalendar
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        return loggedWorkouts.filter { interval.contains($0.date) }
    }

    func workoutsForLastWeek() -> [LoggedWorkout] {
        let calendar = sundayStartCalendar
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: Date()),
              let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: thisWeek.start),
              let lastWeek = calendar.dateInterval(of: .weekOfYear, for: lastWeekStart) else {
            return []
        }

        return loggedWorkouts.filter { lastWeek.contains($0.date) }
    }

    func thisWeekWorkoutCount() -> Int {
        workoutsForThisWeek().count
    }

    func lastWeekWorkoutCount() -> Int {
        workoutsForLastWeek().count
    }

    func recentWorkoutNames(limit: Int = 8) -> [String] {
        Array(uniqueWorkoutNames(from: loggedWorkouts).prefix(limit))
    }

    private func uniqueWorkoutNames(from workouts: [LoggedWorkout]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for workout in workouts {
            let cleanName = workout.workoutName
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let key = cleanName.lowercased()

            guard !key.isEmpty, !seen.contains(key) else { continue }

            seen.insert(key)
            result.append(cleanName)
        }

        return result
    }

    @discardableResult
    func addCategory(
        name: String,
        symbolRaw: String,
        styleRaw: String,
        visibleOnHome: Bool
    ) -> UUID? {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }

        if let existing = category(named: clean) {
            return existing.id
        }

        let nextOrder = (categories.map(\.homeOrder).max() ?? -1) + 1

        let category = WorkoutCategory(
            name: clean,
            symbolRaw: symbolRaw,
            styleRaw: styleRaw,
            isVisibleOnHome: visibleOnHome,
            homeOrder: nextOrder
        )

        categories.append(category)
        saveCategories()
        return category.id
    }

    func updateCategory(
        id: UUID,
        newName: String,
        newSymbolRaw: String,
        newStyleRaw: String,
        visibleOnHome: Bool
    ) {
        let clean = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        guard let idx = categories.firstIndex(where: { $0.id == id }) else { return }

        let oldName = categories[idx].name

        categories[idx].name = clean
        categories[idx].symbolRaw = newSymbolRaw
        categories[idx].styleRaw = newStyleRaw
        categories[idx].isVisibleOnHome = visibleOnHome

        for i in loggedWorkouts.indices where loggedWorkouts[i].categoryID == id {
            loggedWorkouts[i].categoryName = clean
        }

        if oldName != clean {
            saveLoggedWorkouts()
        }
        saveCategories()
    }

    func deleteCategory(_ category: WorkoutCategory) {
        categories.removeAll { $0.id == category.id }
        workoutTypes.removeAll { $0.categoryID == category.id }

        for i in loggedWorkouts.indices where loggedWorkouts[i].categoryID == category.id {
            loggedWorkouts[i].categoryID = nil
        }

        saveCategories()
        saveWorkoutTypes()
        saveLoggedWorkouts()
    }

    func setCategoryVisibleOnHome(_ id: UUID, visible: Bool) {
        guard let idx = categories.firstIndex(where: { $0.id == id }) else { return }
        categories[idx].isVisibleOnHome = visible
        if visible {
            let nextOrder = (categories.map(\.homeOrder).max() ?? -1) + 1
            categories[idx].homeOrder = nextOrder
        }
        saveCategories()
    }

    func addWorkoutType(name: String, categoryID: UUID) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        let exists = workoutTypes.contains {
            $0.categoryID == categoryID && $0.name.lowercased() == clean.lowercased()
        }
        guard !exists else { return }

        workoutTypes.append(WorkoutType(categoryID: categoryID, name: clean))
        saveWorkoutTypes()
    }

    func updateWorkoutType(id: UUID, newName: String, newCategoryID: UUID) {
        let clean = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        guard let index = workoutTypes.firstIndex(where: { $0.id == id }) else { return }

        workoutTypes[index].name = clean
        workoutTypes[index].categoryID = newCategoryID
        saveWorkoutTypes()
    }

    func deleteWorkoutType(_ type: WorkoutType) {
        workoutTypes.removeAll { $0.id == type.id }
        saveWorkoutTypes()
    }

    func addLog(_ log: LoggedWorkout) {
        loggedWorkouts.insert(log, at: 0)
        loggedWorkouts.sort { $0.date > $1.date }
        saveLoggedWorkouts()
    }

    func markLogAsSynced(_ id: UUID, googleEventID: String?) {
        guard let index = loggedWorkouts.firstIndex(where: { $0.id == id }) else { return }
        loggedWorkouts[index].syncedToGoogleCalendar = true
        if let googleEventID {
            loggedWorkouts[index].googleEventID = googleEventID
        }
        saveLoggedWorkouts()
    }

    func removeLog(id: UUID) {
        loggedWorkouts.removeAll { $0.id == id }
        saveLoggedWorkouts()
    }

    func reconcileWithCalendar(_ imported: [LoggedWorkout]) {
        let importedIDs = Set(imported.compactMap(\.googleEventID))

        loggedWorkouts.removeAll { local in
            if let localGoogleID = local.googleEventID {
                return !importedIDs.contains(localGoogleID)
            }
            return false
        }

        for item in imported {
            var resolved = item
            if let match = category(named: item.categoryName) {
                resolved.categoryID = match.id
            }

            if let newID = resolved.googleEventID,
               let existingIndex = loggedWorkouts.firstIndex(where: { $0.googleEventID == newID }) {
                loggedWorkouts[existingIndex] = resolved
            } else {
                let existsByFallback = loggedWorkouts.contains {
                    $0.googleEventID == nil &&
                    $0.workoutName == resolved.workoutName &&
                    $0.categoryName == resolved.categoryName &&
                    Calendar.current.isDate($0.date, equalTo: resolved.date, toGranularity: .minute) &&
                    $0.minutes == resolved.minutes
                }

                if !existsByFallback {
                    loggedWorkouts.append(resolved)
                }
            }
        }

        loggedWorkouts.sort { $0.date > $1.date }
        saveLoggedWorkouts()
    }

    func setSyncEnabled(_ enabled: Bool) {
        syncToGoogleCalendar = enabled
        UserDefaults.standard.set(enabled, forKey: syncKey)
    }

    func setCalendarSyncRange(_ range: CalendarSyncRange) {
        calendarSyncRange = range
        UserDefaults.standard.set(range.rawValue, forKey: syncRangeKey)
    }

    private func saveCategories() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(categories) {
            UserDefaults.standard.set(data, forKey: categoriesKey)
        }
    }

    private func saveWorkoutTypes() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(workoutTypes) {
            UserDefaults.standard.set(data, forKey: workoutTypesKey)
        }
    }

    private func saveLoggedWorkouts() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(loggedWorkouts) {
            UserDefaults.standard.set(data, forKey: loggedWorkoutsKey)
        }
    }
}

// MARK: - Calendar Service

enum CalendarError: LocalizedError {
    case notSignedIn
    case missingToken
    case invalidResponse
    case api(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "You are not signed in to Google."
        case .missingToken:
            return "Google access token is missing."
        case .invalidResponse:
            return "Invalid response from Google Calendar."
        case .api(let message):
            return message
        }
    }
}

struct CalendarCreateEventResponse: Decodable {
    let id: String?
}

struct CalendarEventsResponse: Decodable {
    let items: [CalendarEvent]?
}

struct CalendarEvent: Decodable {
    let id: String?
    let summary: String?
    let description: String?
    let start: CalendarEventDate?
    let end: CalendarEventDate?
}

struct CalendarEventDate: Decodable {
    let dateTime: Date?
    let date: String?
}

@MainActor
final class GoogleCalendarService: ObservableObject {
    @Published var isSignedIn = false
    @Published var userEmail = ""
    @Published var lastError: String?
    @Published var isBusy = false

    private let clientID = "537727697182-snef98do6ubla00c0h6pdrcmtsk0lrtq.apps.googleusercontent.com"

    init() {
        restoreIfPossible()
    }

    func restoreIfPossible() {
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
            guard let self else { return }

            Task { @MainActor in
                if let error {
                    self.lastError = error.localizedDescription
                    self.isSignedIn = false
                    self.userEmail = ""
                    return
                }

                self.isSignedIn = (user != nil)
                self.userEmail = user?.profile?.email ?? ""
                self.lastError = nil
            }
        }
    }

    func signIn() async {
        guard let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else {
            lastError = "Could not find root view controller."
            return
        }

        isBusy = true
        lastError = nil

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: rootVC,
                hint: nil,
                additionalScopes: [
                    "https://www.googleapis.com/auth/calendar.events",
                    "https://www.googleapis.com/auth/calendar.events.readonly"
                ]
            )

            isSignedIn = true
            userEmail = result.user.profile?.email ?? ""
            lastError = nil
        } catch {
            isSignedIn = false
            userEmail = ""
            lastError = error.localizedDescription
        }

        isBusy = false
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        isSignedIn = false
        userEmail = ""
        lastError = nil
    }

    func createWorkoutEvent(for workout: LoggedWorkout) async throws -> String? {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw CalendarError.notSignedIn
        }

        let accessToken = user.accessToken.tokenString
        guard !accessToken.isEmpty else {
            throw CalendarError.missingToken
        }

        let startDate = workout.date
        let endDate = Calendar.current.date(byAdding: .minute, value: workout.minutes, to: startDate)
        ?? startDate.addingTimeInterval(TimeInterval(workout.minutes * 60))

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let descriptionLines = [
            "Category: \(workout.categoryName)",
            "Duration: \(workout.minutes) minutes",
            workout.notes.isEmpty ? nil : "Notes: \(workout.notes)"
        ].compactMap { $0 }

        let payload: [String: Any] = [
            "summary": "Workout - \(workout.workoutName)",
            "description": descriptionLines.joined(separator: "\n"),
            "start": [
                "dateTime": formatter.string(from: startDate)
            ],
            "end": [
                "dateTime": formatter.string(from: endDate)
            ]
        ]

        let requestData = try JSONSerialization.data(withJSONObject: payload)

        var request = URLRequest(url: URL(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = requestData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw CalendarError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown Calendar API error"
            throw CalendarError.api(text)
        }

        let decoder = JSONDecoder()
        let created = try? decoder.decode(CalendarCreateEventResponse.self, from: data)
        return created?.id
    }

    func deleteWorkoutEvent(googleEventID: String) async throws {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw CalendarError.notSignedIn
        }

        let accessToken = user.accessToken.tokenString
        guard !accessToken.isEmpty else {
            throw CalendarError.missingToken
        }

        let encodedID = googleEventID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? googleEventID
        var request = URLRequest(url: URL(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events/\(encodedID)")!)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw CalendarError.invalidResponse
        }

        guard http.statusCode == 204 || (200...299).contains(http.statusCode) else {
            throw CalendarError.api("Failed to delete Google Calendar event.")
        }
    }

    func importWorkoutsFromCalendar(range: CalendarSyncRange) async throws -> [LoggedWorkout] {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw CalendarError.notSignedIn
        }

        let accessToken = user.accessToken.tokenString
        guard !accessToken.isEmpty else {
            throw CalendarError.missingToken
        }

        let base = "https://www.googleapis.com/calendar/v3/calendars/primary/events"
        var queryItems = [
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "maxResults", value: "2500")
        ]

        if let dateFrom = range.dateFrom {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            queryItems.append(URLQueryItem(name: "timeMin", value: formatter.string(from: dateFrom)))
        }

        var components = URLComponents(string: base)!
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw CalendarError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown Calendar API error"
            throw CalendarError.api(text)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)

            let isoWithFractional = ISO8601DateFormatter()
            isoWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoWithFractional.date(from: raw) {
                return date
            }

            let isoPlain = ISO8601DateFormatter()
            isoPlain.formatOptions = [.withInternetDateTime]
            if let date = isoPlain.date(from: raw) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date format: \(raw)"
            )
        }

        let decoded = try decoder.decode(CalendarEventsResponse.self, from: data)
        let items = decoded.items ?? []

        return items.compactMap { event in
            guard let summary = event.summary, summary.hasPrefix("Workout - ") else { return nil }
            guard let start = event.start?.dateTime else { return nil }

            let workoutName = String(summary.dropFirst("Workout - ".count))
            let desc = event.description ?? ""

            let calculatedMinutes: Int
            if let end = event.end?.dateTime {
                let interval = end.timeIntervalSince(start)
                calculatedMinutes = max(Int(interval / 60), 1)
            } else {
                calculatedMinutes = parseMinutes(from: desc) ?? 30
            }

            return LoggedWorkout(
                googleEventID: event.id,
                workoutName: workoutName,
                categoryName: parseCategoryName(from: desc) ?? "Workout",
                minutes: calculatedMinutes,
                notes: parseNotes(from: desc) ?? "",
                date: start,
                syncedToGoogleCalendar: true
            )
        }
    }

    private func parseCategoryName(from description: String) -> String? {
        let prefix = "Category: "
        guard let range = description.range(of: prefix) else { return nil }
        let remainder = description[range.upperBound...]
        let line = remainder.split(separator: "\n").first
        return line.map(String.init)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseMinutes(from description: String) -> Int? {
        let prefix = "Duration: "
        guard let range = description.range(of: prefix) else { return nil }
        let remainder = description[range.upperBound...]
        let numberString = remainder.prefix { $0.isNumber }
        return Int(numberString)
    }

    private func parseNotes(from description: String) -> String? {
        let prefix = "Notes: "
        guard let range = description.range(of: prefix) else { return nil }
        return String(description[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Home
struct HomeTileDropDelegate: DropDelegate {
    let item: WorkoutCategory
    @Binding var draggedItem: WorkoutCategory?
    let store: WorkoutStore

    func dropEntered(info: DropInfo) {
        guard let draggedItem else { return }
        guard draggedItem.id != item.id else { return }

        store.moveHomeCategory(from: draggedItem.id, to: item.id)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        if !info.hasItemsConforming(to: [UTType.text]) {
            draggedItem = nil
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var calendarService: GoogleCalendarService

    @Binding var selectedTab: ContentView.AppTab
    @Binding var selectedCategoryID: UUID?
    @Binding var showingAddWorkout: Bool

    @State private var draggedCategory: WorkoutCategory?
    @State private var editMode = false
    @State private var editSessionID = UUID()

    private var thisWeekWorkoutCount: Int {
        store.thisWeekWorkoutCount()
    }

    private var lastWeekWorkoutCount: Int {
        store.lastWeekWorkoutCount()
    }

    private var recentWorkoutNames: [String] {
        store.recentWorkoutNames(limit: 8)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [.black, Color(red: 0.08, green: 0.08, blue: 0.13)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Muscle Metrics")
                            .font(.system(size: 36, weight: .bold, design: .rounded))

                        if let banner = store.homeBannerMessage {
                            Text(banner)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(.ultraThinMaterial.opacity(0.25), in: Capsule())
                        }

                        HStack(spacing: 14) {
                            CompactStatCard(
                                title: "This Week",
                                count: thisWeekWorkoutCount
                            )

                            CompactStatCard(
                                title: "Last Week",
                                count: lastWeekWorkoutCount
                            )
                        }

                        ActivityChipsCard(
                            title: "Recent Activity",
                            workouts: recentWorkoutNames
                        )

                        HStack {
                            Text("Workouts")
                                .font(.title3.bold())

                            Spacer()

                            if editMode {
                                Button {
                                    showingAddWorkout = true
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.headline.bold())
                                        .padding(10)
                                        .background(.ultraThinMaterial, in: Circle())
                                }

                                Button("Done") {
                                    withAnimation(.easeInOut) {
                                        editMode = false
                                        draggedCategory = nil
                                        editSessionID = UUID()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            } else {
                                Button("Edit") {
                                    withAnimation(.easeInOut) {
                                        editMode = true
                                        draggedCategory = nil
                                        editSessionID = UUID()
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                        }

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(store.homeCategories()) { category in
                                HomeCategoryTile(
                                    category: category,
                                    typeCount: store.workouts(for: category.id).count,
                                    editMode: editMode,
                                    onTap: {
                                        if !editMode {
                                            selectedCategoryID = category.id
                                            selectedTab = .workout
                                        }
                                    },
                                    onHide: {
                                        store.setCategoryVisibleOnHome(category.id, visible: false)
                                        if selectedCategoryID == category.id {
                                            selectedCategoryID = store.homeCategories().first?.id ?? store.categories.first?.id
                                        }
                                    }
                                )
                                .id("\(category.id.uuidString)-\(editMode)-\(editSessionID.uuidString)")
                                .onDrag {
                                    guard editMode else {
                                        return NSItemProvider()
                                    }
                                    draggedCategory = category
                                    return NSItemProvider(object: NSString(string: category.id.uuidString))
                                }
                                .onDrop(
                                    of: [UTType.text],
                                    delegate: HomeTileDropDelegate(
                                        item: category,
                                        draggedItem: $draggedCategory,
                                        store: store
                                    )
                                )
                            }
                        }
                    }
                    .padding()
                }
                .refreshable {
                    guard calendarService.isSignedIn else {
                        store.showHomeBanner("Connect Google Calendar in Settings first.")
                        return
                    }

                    do {
                        let imported = try await calendarService.importWorkoutsFromCalendar(range: store.calendarSyncRange)
                        store.reconcileWithCalendar(imported)
                        store.showHomeBanner("Calendar refreshed.")
                    } catch {
                        store.showHomeBanner("Calendar refresh failed.")
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct HomeCategoryTile: View {
    let category: WorkoutCategory
    let typeCount: Int
    let editMode: Bool
    let onTap: () -> Void
    let onHide: () -> Void

    @State private var wiggle = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(category.gradient)
                .frame(maxWidth: .infinity, minHeight: 88)
                .overlay(
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: category.symbol)
                            .font(.title3)

                        Text(category.name)
                            .font(.subheadline.weight(.semibold))

                        Text("\(typeCount) types")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
                    .padding()
                )
                .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .onTapGesture {
                    onTap()
                }
                .rotationEffect(.degrees(editMode ? (wiggle ? 1.2 : -1.2) : 0))
                .scaleEffect(editMode ? 0.995 : 1.0)
                .onAppear {
                    restartWiggleIfNeeded()
                }
                .onChange(of: editMode) { _, _ in
                    restartWiggleIfNeeded()
                }

            if editMode {
                Button {
                    onHide()
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white, .red)
                        .background(Circle().fill(.white))
                }
                .offset(x: -8, y: -8)
                .zIndex(10)
            }
        }
    }

    private func restartWiggleIfNeeded() {
        if editMode {
            wiggle = false
            withAnimation(.easeInOut(duration: 0.12).repeatForever(autoreverses: true)) {
                wiggle = true
            }
        } else {
            wiggle = false
        }
    }
}

// MARK: - Workout

struct LogWorkoutView: View {
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var calendarService: GoogleCalendarService

    @Binding var selectedCategoryID: UUID?
    @Binding var selectedTab: ContentView.AppTab

    @State private var selectedTypeID: UUID?
    @State private var selectedMinutes = 60
    @State private var notes = ""
    @State private var logDate = Date()
    @State private var isSaving = false
    @State private var saveMessage = ""
    @FocusState private var notesFocused: Bool
    @State private var keyboardIsVisible = false

    private let minuteOptions = Array(stride(from: 5, through: 240, by: 5))

    private var selectedCategory: WorkoutCategory? {
        store.category(by: selectedCategoryID)
    }

    private var filteredWorkouts: [WorkoutType] {
        store.workouts(for: selectedCategoryID)
    }

    private var normalizedCategoryName: String {
        selectedCategory?.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    }

    private var subtypeOptions: [WorkoutType] {
        if filteredWorkouts.count <= 1 {
            return []
        }

        let nonDuplicateOptions = filteredWorkouts.filter {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != normalizedCategoryName
        }

        return nonDuplicateOptions
    }

    private var shouldShowWorkoutPicker: Bool {
        !subtypeOptions.isEmpty
    }

    private var selectedType: WorkoutType? {
        guard let selectedTypeID else { return nil }
        return store.workoutTypes.first(where: { $0.id == selectedTypeID })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [.black, Color(red: 0.08, green: 0.09, blue: 0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Form {
                    Section("Workout") {
                        Picker("Category", selection: Binding(
                            get: { selectedCategoryID ?? store.categories.first?.id },
                            set: { selectedCategoryID = $0 }
                        )) {
                            ForEach(store.categoriesSorted()) { category in
                                Text(category.name).tag(Optional(category.id))
                            }
                        }
                        .onChange(of: selectedCategoryID) { _, _ in
                            if let firstSubtype = subtypeOptions.first {
                                selectedTypeID = firstSubtype.id
                            } else {
                                selectedTypeID = filteredWorkouts.first?.id
                            }
                        }

                        if shouldShowWorkoutPicker {
                            Picker("Workout", selection: $selectedTypeID) {
                                ForEach(subtypeOptions) { type in
                                    Text(type.name).tag(Optional(type.id))
                                }
                            }
                        }
                    }

                    Section("Details") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Minutes")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Picker("Minutes", selection: $selectedMinutes) {
                                ForEach(minuteOptions, id: \.self) { value in
                                    Text("\(value) min").tag(value)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 120)
                        }

                        DatePicker("Date", selection: $logDate)

                        TextField("Notes", text: $notes, axis: .vertical)
                            .lineLimit(2...4)
                            .focused($notesFocused)
                    }

                    Section {
                        Button {
                            Task { await saveWorkout() }
                        } label: {
                            HStack {
                                Spacer()
                                if isSaving {
                                    ProgressView()
                                } else {
                                    Text("Save Workout")
                                        .fontWeight(.bold)
                                }
                                Spacer()
                            }
                        }
                        .disabled(isSaving || selectedCategory == nil)
                    }

                    if !saveMessage.isEmpty {
                        Section {
                            Text(saveMessage)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                    keyboardIsVisible = true
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                    keyboardIsVisible = false
                }
                .safeAreaInset(edge: .bottom) {
                    if keyboardIsVisible && notesFocused {
                        HStack {
                            Spacer()
                            Button("Done") {
                                notesFocused = false
                                UIApplication.shared.sendAction(
                                    #selector(UIResponder.resignFirstResponder),
                                    to: nil,
                                    from: nil,
                                    for: nil
                                )
                            }
                            .font(.headline)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(.trailing, 16)
                            .padding(.bottom, 6)
                        }
                    }
                }
            }
            .navigationTitle("Log Workout")
            .onAppear {
                if selectedCategoryID == nil {
                    selectedCategoryID = store.homeCategories().first?.id ?? store.categories.first?.id
                }

                if let firstSubtype = subtypeOptions.first {
                    selectedTypeID = firstSubtype.id
                } else {
                    selectedTypeID = filteredWorkouts.first?.id
                }
            }
        }
    }

    private func saveWorkout() async {
        guard let selectedCategory else { return }

        isSaving = true
        saveMessage = ""

        let workoutName = selectedType?.name ?? selectedCategory.name

        let log = LoggedWorkout(
            typeID: selectedType?.id,
            categoryID: selectedCategory.id,
            workoutName: workoutName,
            categoryName: selectedCategory.name,
            minutes: selectedMinutes,
            notes: notes,
            date: logDate,
            syncedToGoogleCalendar: false
        )

        store.addLog(log)

        var bannerText = "Workout saved."

        if store.syncToGoogleCalendar && calendarService.isSignedIn {
            do {
                let googleEventID = try await calendarService.createWorkoutEvent(for: log)
                store.markLogAsSynced(log.id, googleEventID: googleEventID)

                let imported = try await calendarService.importWorkoutsFromCalendar(range: store.calendarSyncRange)
                store.reconcileWithCalendar(imported)

                bannerText = "Workout saved and synced to Google Calendar."
            } catch {
                bannerText = "Workout saved, but calendar sync failed."
            }
        }

        store.showHomeBanner(bannerText)

        notes = ""
        notesFocused = false
        keyboardIsVisible = false
        isSaving = false
        saveMessage = ""

        selectedTab = .home
    }
}

// MARK: - History

struct MonthSection: Identifiable {
    let id: String
    let title: String
    let workouts: [LoggedWorkout]
    let weeks: [WeekSection]
}

struct WeekSection: Identifiable {
    let id: String
    let title: String
    let workouts: [LoggedWorkout]
}

struct HistoryView: View {
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var calendarService: GoogleCalendarService

    @State private var expandedMonths: Set<String> = []
    @State private var expandedWeeks: Set<String> = []
    @State private var deleteMessage = ""

    private var recentWorkouts: [LoggedWorkout] {
        Array(store.loggedWorkouts.prefix(5))
    }

    private var remainingWorkouts: [LoggedWorkout] {
        Array(store.loggedWorkouts.dropFirst(5))
    }

    private var monthSections: [MonthSection] {
        let calendar = Calendar.current
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM yyyy"

        let weekFormatter = DateFormatter()
        weekFormatter.dateFormat = "MMM d"

        let groupedByMonth = Dictionary(grouping: remainingWorkouts) {
            let comps = calendar.dateComponents([.year, .month], from: $0.date)
            return "\(comps.year ?? 0)-\(comps.month ?? 0)"
        }

        return groupedByMonth.compactMap { key, values in
            guard let first = values.first else { return nil }
            let monthTitle = monthFormatter.string(from: first.date)

            let groupedByWeek = Dictionary(grouping: values) {
                let interval = calendar.dateInterval(of: .weekOfYear, for: $0.date)
                let start = interval?.start ?? $0.date
                return start
            }

            let weeks = groupedByWeek
                .map { startDate, weekWorkouts in
                    let endDate = calendar.date(byAdding: .day, value: 6, to: startDate) ?? startDate
                    let title = "\(weekFormatter.string(from: startDate)) - \(weekFormatter.string(from: endDate))"
                    return WeekSection(
                        id: "\(key)-\(startDate.timeIntervalSince1970)",
                        title: title,
                        workouts: weekWorkouts.sorted { $0.date > $1.date }
                    )
                }
                .sorted {
                    ($0.workouts.first?.date ?? .distantPast) > ($1.workouts.first?.date ?? .distantPast)
                }

            return MonthSection(
                id: key,
                title: monthTitle,
                workouts: values.sorted { $0.date > $1.date },
                weeks: weeks
            )
        }
        .sorted {
            ($0.workouts.first?.date ?? .distantPast) > ($1.workouts.first?.date ?? .distantPast)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ZStack {
                    LinearGradient(
                        colors: [.black, Color(red: 0.10, green: 0.10, blue: 0.14)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()

                    VStack(spacing: 12) {
                        if !deleteMessage.isEmpty {
                            Text(deleteMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                                .padding(.top)
                        }

                        if store.loggedWorkouts.isEmpty {
                            EmptyStateCard(title: "No workout history", subtitle: "Your completed workouts will appear here.")
                                .padding()
                            Spacer()
                        } else {
                            List {
                                if !recentWorkouts.isEmpty {
                                    Section {
                                        ForEach(recentWorkouts) { workout in
                                            WorkoutLogCard(workout: workout)
                                                .listRowBackground(Color.clear)
                                                .swipeActions {
                                                    Button(role: .destructive) {
                                                        Task { await deleteWorkout(workout) }
                                                    } label: {
                                                        Label("Delete", systemImage: "trash")
                                                    }
                                                }
                                        }
                                    } header: {
                                        Text("Recent Workouts")
                                    }
                                }

                                ForEach(monthSections) { month in
                                    Section {
                                        DisclosureGroup(
                                            isExpanded: Binding(
                                                get: { expandedMonths.contains(month.id) },
                                                set: { isExpanded in
                                                    if isExpanded {
                                                        expandedMonths.insert(month.id)
                                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                                            withAnimation {
                                                                proxy.scrollTo(month.id, anchor: .top)
                                                            }
                                                        }
                                                    } else {
                                                        expandedMonths.remove(month.id)
                                                    }
                                                }
                                            )
                                        ) {
                                            ForEach(month.weeks) { week in
                                                DisclosureGroup(
                                                    isExpanded: Binding(
                                                        get: { expandedWeeks.contains(week.id) },
                                                        set: { isExpanded in
                                                            if isExpanded {
                                                                expandedWeeks.insert(week.id)
                                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                                                    withAnimation {
                                                                        proxy.scrollTo(week.id, anchor: .top)
                                                                    }
                                                                }
                                                            } else {
                                                                expandedWeeks.remove(week.id)
                                                            }
                                                        }
                                                    )
                                                ) {
                                                    ForEach(week.workouts) { workout in
                                                        WorkoutLogCard(workout: workout)
                                                            .listRowBackground(Color.clear)
                                                            .swipeActions {
                                                                Button(role: .destructive) {
                                                                    Task { await deleteWorkout(workout) }
                                                                } label: {
                                                                    Label("Delete", systemImage: "trash")
                                                                }
                                                            }
                                                    }
                                                } label: {
                                                    Text(week.title)
                                                        .font(.subheadline.weight(.semibold))
                                                        .id(week.id)
                                                }
                                            }
                                        } label: {
                                            Text(month.title)
                                                .font(.headline)
                                                .id(month.id)
                                        }
                                    }
                                    .listRowBackground(Color.clear)
                                }
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
    }

    private func deleteWorkout(_ workout: LoggedWorkout) async {
        do {
            if let googleID = workout.googleEventID, calendarService.isSignedIn {
                try await calendarService.deleteWorkoutEvent(googleEventID: googleID)
            }

            store.removeLog(id: workout.id)

            if calendarService.isSignedIn {
                let imported = try await calendarService.importWorkoutsFromCalendar(range: store.calendarSyncRange)
                store.reconcileWithCalendar(imported)
            }

            showTemporaryDeleteMessage("Workout deleted.")
        } catch {
            showTemporaryDeleteMessage("Delete failed: \(error.localizedDescription)")
        }
    }

    private func showTemporaryDeleteMessage(_ message: String) {
        deleteMessage = message

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if deleteMessage == message {
                deleteMessage = ""
            }
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject private var store: WorkoutStore
    @EnvironmentObject private var calendarService: GoogleCalendarService

    @State private var showingAddWorkoutType = false
    @State private var showingAddCategory = false
    @State private var editingType: WorkoutType?
    @State private var editingCategory: WorkoutCategory?
    @State private var importMessage = ""
    @State private var isImporting = false
    @State private var expandedFamilies: Set<String> = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Google Calendar") {
                    if calendarService.isSignedIn {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)

                            VStack(alignment: .leading) {
                                Text("Connected")
                                Text(calendarService.userEmail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Toggle("Sync new workouts to Google Calendar", isOn: Binding(
                            get: { store.syncToGoogleCalendar },
                            set: { store.setSyncEnabled($0) }
                        ))

                        Picker("Sync Range", selection: Binding(
                            get: { store.calendarSyncRange },
                            set: { store.setCalendarSyncRange($0) }
                        )) {
                            ForEach(CalendarSyncRange.allCases) { range in
                                Text(range.title).tag(range)
                            }
                        }

                        Button {
                            Task { await importFromCalendar() }
                        } label: {
                            HStack {
                                if isImporting {
                                    ProgressView()
                                }
                                Text("Sync Now")
                            }
                        }

                        if !importMessage.isEmpty {
                            Text(importMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Button("Disconnect Google") {
                            calendarService.signOut()
                        }
                        .foregroundStyle(.red)
                    } else {
                        GoogleSignInButton {
                            Task {
                                await calendarService.signIn()
                            }
                        }
                        .frame(height: 50)
                    }

                    if let error = calendarService.lastError, !error.isEmpty {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Section("Workouts") {
                    Button {
                        showingAddCategory = true
                    } label: {
                        Label("Add Workout", systemImage: "plus.circle")
                    }

                    ForEach(store.categoriesSorted()) { category in
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { expandedFamilies.contains(category.id.uuidString) },
                                set: { isExpanded in
                                    if isExpanded { expandedFamilies.insert(category.id.uuidString) }
                                    else { expandedFamilies.remove(category.id.uuidString) }
                                }
                            )
                        ) {
                            Toggle("Show on Home", isOn: Binding(
                                get: { store.category(by: category.id)?.isVisibleOnHome ?? false },
                                set: { store.setCategoryVisibleOnHome(category.id, visible: $0) }
                            ))

                            HStack {
                                Button("Edit") {
                                    editingCategory = category
                                }
                                .buttonStyle(.borderless)

                                Spacer()

                                Button(role: .destructive) {
                                    store.deleteCategory(category)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                        } label: {
                            HStack {
                                Image(systemName: category.symbol)
                                Text(category.name)
                                Spacer()
                                Text("\(store.workouts(for: category.id).count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Workout Types") {
                    Button {
                        showingAddWorkoutType = true
                    } label: {
                        Label("Add Workout Type", systemImage: "plus.circle")
                    }

                    ForEach(store.groupedWorkoutTypes(), id: \.category.id) { group in
                        if !group.items.isEmpty {
                            DisclosureGroup {
                                ForEach(group.items) { item in
                                    HStack {
                                        Text(item.name)
                                        Spacer()

                                        Button("Edit") {
                                            editingType = item
                                        }
                                        .buttonStyle(.borderless)

                                        Button(role: .destructive) {
                                            store.deleteWorkoutType(item)
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: group.category.symbol)
                                    Text(group.category.name)
                                    Spacer()
                                    Text("\(group.items.count)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAddWorkoutType) {
                AddWorkoutTypeSheet()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showingAddCategory) {
                AddCategorySheet()
                    .environmentObject(store)
            }
            .sheet(item: $editingType) { item in
                EditWorkoutTypeSheet(type: item)
                    .environmentObject(store)
            }
            .sheet(item: $editingCategory) { category in
                EditCategorySheet(category: category)
                    .environmentObject(store)
            }
        }
    }

    private func importFromCalendar() async {
        isImporting = true
        importMessage = ""

        do {
            let imported = try await calendarService.importWorkoutsFromCalendar(range: store.calendarSyncRange)
            store.reconcileWithCalendar(imported)
            showTemporaryImportMessage("Calendar sync complete.")
        } catch {
            showTemporaryImportMessage("Sync failed: \(error.localizedDescription)")
        }

        isImporting = false
    }

    private func showTemporaryImportMessage(_ message: String) {
        importMessage = message

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if importMessage == message {
                importMessage = ""
            }
        }
    }
}

// MARK: - Add / Edit Sheets

struct AddCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: WorkoutStore

    @State private var familyName = ""
    @State private var selectedSymbol: CategorySymbol = .star
    @State private var selectedStyle: TileStyle = .indigoTeal
    @State private var showOnHome = true
    @FocusState private var nameFocused: Bool
    @State private var keyboardIsVisible = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Workout Name", text: $familyName)
                    .focused($nameFocused)

                Picker("Icon", selection: $selectedSymbol) {
                    ForEach(CategorySymbol.allCases) { symbol in
                        Label(symbol.title, systemImage: symbol.rawValue).tag(symbol)
                    }
                }

                Picker("Tile Style", selection: $selectedStyle) {
                    ForEach(TileStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }

                Toggle("Show on Home", isOn: $showOnHome)
            }
            .navigationTitle("Add Family")
            .scrollDismissesKeyboard(.interactively)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                keyboardIsVisible = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardIsVisible = false
            }
            .safeAreaInset(edge: .bottom) {
                if keyboardIsVisible && nameFocused {
                    doneCapsule { nameFocused = false }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        _ = store.addCategory(
                            name: familyName,
                            symbolRaw: selectedSymbol.rawValue,
                            styleRaw: selectedStyle.rawValue,
                            visibleOnHome: showOnHome
                        )
                        dismiss()
                    }
                    .disabled(familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct EditCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: WorkoutStore

    let category: WorkoutCategory
    @State private var familyName: String
    @State private var selectedSymbol: CategorySymbol
    @State private var selectedStyle: TileStyle
    @State private var showOnHome: Bool
    @FocusState private var nameFocused: Bool
    @State private var keyboardIsVisible = false

    init(category: WorkoutCategory) {
        self.category = category
        _familyName = State(initialValue: category.name)
        _selectedSymbol = State(initialValue: CategorySymbol(rawValue: category.symbolRaw) ?? .star)
        _selectedStyle = State(initialValue: TileStyle(rawValue: category.styleRaw) ?? .indigoTeal)
        _showOnHome = State(initialValue: category.isVisibleOnHome)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Workout Name", text: $familyName)
                    .focused($nameFocused)

                Picker("Icon", selection: $selectedSymbol) {
                    ForEach(CategorySymbol.allCases) { symbol in
                        Label(symbol.title, systemImage: symbol.rawValue).tag(symbol)
                    }
                }

                Picker("Tile Style", selection: $selectedStyle) {
                    ForEach(TileStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }

                Toggle("Show on Home", isOn: $showOnHome)
            }
            .navigationTitle("Edit Workout")
            .scrollDismissesKeyboard(.interactively)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                keyboardIsVisible = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardIsVisible = false
            }
            .safeAreaInset(edge: .bottom) {
                if keyboardIsVisible && nameFocused {
                    doneCapsule { nameFocused = false }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateCategory(
                            id: category.id,
                            newName: familyName,
                            newSymbolRaw: selectedSymbol.rawValue,
                            newStyleRaw: selectedStyle.rawValue,
                            visibleOnHome: showOnHome
                        )
                        dismiss()
                    }
                    .disabled(familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct AddWorkoutTypeSheet: View {
    enum FamilyMode: String, CaseIterable, Identifiable {
        case existing
        case new
        var id: String { rawValue }

        var title: String {
            switch self {
            case .existing: return "Existing Workout"
            case .new: return "New Workout"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: WorkoutStore

    @State private var workoutName = ""
    @State private var familyMode: FamilyMode = .existing
    @State private var selectedCategoryID: UUID?
    @State private var newFamilyName = ""
    @State private var selectedSymbol: CategorySymbol = .star
    @State private var selectedStyle: TileStyle = .indigoTeal
    @State private var showOnHome = true
    @FocusState private var workoutFocused: Bool
    @FocusState private var familyFocused: Bool
    @State private var keyboardIsVisible = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Workout Name", text: $workoutName)
                    .focused($workoutFocused)

                Picker("Workout", selection: $familyMode) {
                    ForEach(FamilyMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if familyMode == .existing {
                    Picker("Choose Workout", selection: Binding(
                        get: { selectedCategoryID ?? store.categoriesSorted().first?.id },
                        set: { selectedCategoryID = $0 }
                    )) {
                        ForEach(store.categoriesSorted()) { category in
                            Text(category.name).tag(Optional(category.id))
                        }
                    }
                } else {
                    TextField("New Workout Name", text: $newFamilyName)
                        .focused($familyFocused)

                    Picker("Icon", selection: $selectedSymbol) {
                        ForEach(CategorySymbol.allCases) { symbol in
                            Label(symbol.title, systemImage: symbol.rawValue).tag(symbol)
                        }
                    }

                    Picker("Tile Style", selection: $selectedStyle) {
                        ForEach(TileStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }

                    Toggle("Show Workout on Home Screen", isOn: $showOnHome)
                }
            }
            .navigationTitle("Add Workout")
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                if selectedCategoryID == nil {
                    selectedCategoryID = store.categoriesSorted().first?.id
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                keyboardIsVisible = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardIsVisible = false
            }
            .safeAreaInset(edge: .bottom) {
                if keyboardIsVisible && (workoutFocused || familyFocused) {
                    doneCapsule {
                        workoutFocused = false
                        familyFocused = false
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        let workoutOK = !workoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        switch familyMode {
        case .existing:
            return workoutOK && selectedCategoryID != nil
        case .new:
            return workoutOK && !newFamilyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func save() {
        if familyMode == .existing {
            guard let selectedCategoryID else { return }
            store.addWorkoutType(name: workoutName, categoryID: selectedCategoryID)
        } else {
            guard let newID = store.addCategory(
                name: newFamilyName,
                symbolRaw: selectedSymbol.rawValue,
                styleRaw: selectedStyle.rawValue,
                visibleOnHome: showOnHome
            ) else { return }
            store.addWorkoutType(name: workoutName, categoryID: newID)
        }
        dismiss()
    }
}

struct EditWorkoutTypeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: WorkoutStore

    let type: WorkoutType
    @State private var name: String
    @State private var selectedCategoryID: UUID?
    @FocusState private var nameFocused: Bool
    @State private var keyboardIsVisible = false

    init(type: WorkoutType) {
        self.type = type
        _name = State(initialValue: type.name)
        _selectedCategoryID = State(initialValue: type.categoryID)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Workout Name", text: $name)
                    .focused($nameFocused)

                Picker("Workout", selection: Binding(
                    get: { selectedCategoryID ?? store.categoriesSorted().first?.id },
                    set: { selectedCategoryID = $0 }
                )) {
                    ForEach(store.categoriesSorted()) { category in
                        Text(category.name).tag(Optional(category.id))
                    }
                }
            }
            .navigationTitle("Edit Workout Type")
            .scrollDismissesKeyboard(.interactively)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                keyboardIsVisible = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardIsVisible = false
            }
            .safeAreaInset(edge: .bottom) {
                if keyboardIsVisible && nameFocused {
                    doneCapsule { nameFocused = false }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let selectedCategoryID else { return }
                        store.updateWorkoutType(id: type.id, newName: name, newCategoryID: selectedCategoryID)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCategoryID == nil)
                }
            }
        }
    }
}

// MARK: - Reusable Views
struct CompactStatCard: View {
    let title: String
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .foregroundStyle(.secondary)
                .font(.subheadline)

            Text("\(count)")
                .font(.system(size: 30, weight: .bold, design: .rounded))

            Text(count == 1 ? "workout" : "workouts")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding()
        .background(.ultraThinMaterial.opacity(0.22), in: RoundedRectangle(cornerRadius: 20))
    }
}

struct ActivityChipsCard: View {
    let title: String
    let workouts: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if workouts.isEmpty {
                Text("No workouts yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                FlexibleChipsView(items: workouts)
            }
        }
        .padding()
        .background(.ultraThinMaterial.opacity(0.18), in: RoundedRectangle(cornerRadius: 20))
    }
}

struct FlexibleChipsView: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(chunked(items, size: 3), id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { item in
                        Text(item)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.92))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.08), in: Capsule())
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func chunked(_ array: [String], size: Int) -> [[String]] {
        stride(from: 0, to: array.count, by: size).map {
            Array(array[$0..<min($0 + size, array.count)])
        }
    }
}

struct WorkoutLogCard: View {
    let workout: LoggedWorkout

    private var dateText: String {
        workout.date.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .frame(width: 46, height: 46)
                .overlay {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .foregroundStyle(.white)
                        .font(.subheadline)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.workoutName)
                    .font(.headline)

                Text("\(workout.minutes) min • \(workout.categoryName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(dateText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !workout.notes.isEmpty {
                    Text(workout.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if workout.syncedToGoogleCalendar {
                Image(systemName: "calendar.badge.checkmark")
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(.ultraThinMaterial.opacity(0.18), in: RoundedRectangle(cornerRadius: 22))
    }
}

struct EmptyStateCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.largeTitle)

            Text(title)
                .font(.headline)

            Text(subtitle)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(.ultraThinMaterial.opacity(0.16), in: RoundedRectangle(cornerRadius: 24))
    }
}

@ViewBuilder
func doneCapsule(action: @escaping () -> Void) -> some View {
    HStack {
        Spacer()
        Button("Done") {
            action()
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
        .font(.headline)
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.trailing, 16)
        .padding(.bottom, 6)
    }
}
