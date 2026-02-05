import Foundation

// MARK: - Nami Stats Service

/// Manages XP calculation and level progression for Nami entity
@Observable
final class NamiStatsService {
    // MARK: - Properties

    private(set) var totalXP: Int = 0
    private(set) var level: Int = 1
    private(set) var levelProgress: Double = 0.0
    private(set) var levelName: String = "Ripple"

    // Stats from backend
    var totalMessages: Int = 0 { didSet { recalculate() } }
    var totalConversations: Int = 0 { didSet { recalculate() } }
    var memoriesStored: Int = 0 { didSet { recalculate() } }
    var skillsCreated: Int = 0 { didSet { recalculate() } }
    var daysActive: Int = 0 { didSet { recalculate() } }
    var voiceMinutesUsed: Int = 0 { didSet { recalculate() } }

    // MARK: - XP Constants

    private let xpPerMessage = 1
    private let xpPerConversation = 10
    private let xpPerMemorySaved = 5
    private let xpPerSkillCreated = 50
    private let xpPerDayActive = 20
    private let xpPerVoiceMinute = 2

    // MARK: - Init

    init() {
        load()
        recalculate()
    }

    // MARK: - Level Calculation

    /// XP required for a specific level (exponential growth)
    func xpForLevel(_ level: Int) -> Int {
        return Int(pow(Double(level), 2.5) * 100)
    }

    /// Level name based on level number (wave-themed)
    func nameForLevel(_ level: Int) -> String {
        switch level {
        case 1...2: return "Ripple"      // 波紋 (hamon) - small wave
        case 3...4: return "Surge"       // 高潮 (takashio) - rising tide
        case 5...6: return "Current"     // 流れ (nagare) - flow
        case 7...8: return "Tsunami"     // 津波 - great wave
        case 9...10: return "Ocean"      // 海 (umi) - vast ocean
        default: return "Ripple"
        }
    }

    /// Recalculate XP, level, and progress
    private func recalculate() {
        // Calculate total XP
        totalXP = (totalMessages * xpPerMessage) +
                  (totalConversations * xpPerConversation) +
                  (memoriesStored * xpPerMemorySaved) +
                  (skillsCreated * xpPerSkillCreated) +
                  (daysActive * xpPerDayActive) +
                  (voiceMinutesUsed * xpPerVoiceMinute)

        // Calculate level from XP
        var currentLevel = 1
        var xpForCurrentLevel = xpForLevel(1)
        var xpForNextLevel = xpForLevel(2)

        while currentLevel < 10 && totalXP >= xpForNextLevel {
            currentLevel += 1
            xpForCurrentLevel = xpForNextLevel
            xpForNextLevel = xpForLevel(currentLevel + 1)
        }

        level = currentLevel
        levelName = nameForLevel(level)

        // Calculate progress to next level
        if currentLevel >= 10 {
            levelProgress = 1.0
        } else {
            let xpIntoCurrentLevel = totalXP - xpForCurrentLevel
            let xpNeededForNextLevel = xpForNextLevel - xpForCurrentLevel
            levelProgress = Double(xpIntoCurrentLevel) / Double(xpNeededForNextLevel)
        }

        save()
    }

    // MARK: - Actions

    func addMessage() {
        totalMessages += 1
    }

    func addConversation() {
        totalConversations += 1
    }

    func addMemory() {
        memoriesStored += 1
    }

    func addSkill() {
        skillsCreated += 1
    }

    func addVoiceMinute() {
        voiceMinutesUsed += 1
    }

    func checkDayActive() {
        let lastActiveKey = "com.nami.lastActiveDate"
        let today = Calendar.current.startOfDay(for: Date())

        if let lastActive = UserDefaults.standard.object(forKey: lastActiveKey) as? Date {
            let lastActiveDay = Calendar.current.startOfDay(for: lastActive)
            if today > lastActiveDay {
                daysActive += 1
                UserDefaults.standard.set(today, forKey: lastActiveKey)
            }
        } else {
            daysActive = 1
            UserDefaults.standard.set(today, forKey: lastActiveKey)
        }
    }

    // MARK: - Persistence

    private let storageKey = "com.nami.stats"

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let stats = try? JSONDecoder().decode(StoredStats.self, from: data) else {
            return
        }
        totalMessages = stats.totalMessages
        totalConversations = stats.totalConversations
        memoriesStored = stats.memoriesStored
        skillsCreated = stats.skillsCreated
        daysActive = stats.daysActive
        voiceMinutesUsed = stats.voiceMinutesUsed
    }

    private func save() {
        let stats = StoredStats(
            totalMessages: totalMessages,
            totalConversations: totalConversations,
            memoriesStored: memoriesStored,
            skillsCreated: skillsCreated,
            daysActive: daysActive,
            voiceMinutesUsed: voiceMinutesUsed
        )
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private struct StoredStats: Codable {
        let totalMessages: Int
        let totalConversations: Int
        let memoriesStored: Int
        let skillsCreated: Int
        let daysActive: Int
        let voiceMinutesUsed: Int
    }

    // MARK: - Sync from Backend

    /// Update stats from backend /api/soul response
    func updateFromBackend(stats: [String: Int]) {
        if let messages = stats["totalMessages"] { totalMessages = messages }
        if let conversations = stats["totalConversations"] { totalConversations = conversations }
        if let memories = stats["memoriesStored"] { memoriesStored = memories }
        if let skills = stats["skillsCreated"] { skillsCreated = skills }
        if let days = stats["daysActive"] { daysActive = days }
        if let voice = stats["voiceMinutesUsed"] { voiceMinutesUsed = voice }
    }
}
