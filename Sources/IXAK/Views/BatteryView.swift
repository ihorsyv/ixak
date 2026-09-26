import SwiftUI

struct BatteryView: View {
    @State private var battery: BatteryInfo?
    @State private var noBattery = false
    @State private var isRefreshing = false
    @State private var lastUpdated: Date?

    var body: some View {
        Form {
            if let battery {
                Section {
                    LabeledContent {
                        BilingualLabel(battery.condition)
                    } label: {
                        BilingualLabel(en: "Condition", ru: "Состояние")
                    }
                    LabeledContent {
                        Text(String(format: "%.1f%%", battery.healthPercent))
                    } label: {
                        BilingualLabel(en: "Health", ru: "Износ")
                    }
                    LabeledContent {
                        Text("\(battery.cycleCount)")
                    } label: {
                        BilingualLabel(en: "Cycle Count", ru: "Циклы заряда")
                    }
                    LabeledContent {
                        Text("\(battery.designCapacity) mAh")
                    } label: {
                        BilingualLabel(en: "Design Capacity", ru: "Проектная ёмкость")
                    }
                    LabeledContent {
                        Text("\(battery.maxCapacity) mAh")
                    } label: {
                        BilingualLabel(en: "Current Max Capacity", ru: "Текущая максимальная ёмкость")
                    }
                } header: {
                    BilingualLabel(en: "Health", ru: "Здоровье")
                }

                Section {
                    LabeledContent {
                        Text(String(format: "%.0f%%", battery.chargePercent))
                    } label: {
                        BilingualLabel(en: "Charge", ru: "Заряд")
                    }
                    LabeledContent {
                        BilingualLabel(en: battery.isCharging ? "Yes" : "No", ru: battery.isCharging ? "Да" : "Нет")
                    } label: {
                        BilingualLabel(en: "Charging", ru: "Заряжается")
                    }
                    if let temp = battery.temperatureCelsius {
                        LabeledContent {
                            Text(String(format: "%.1f°C", temp))
                        } label: {
                            BilingualLabel(en: "Temperature", ru: "Температура")
                        }
                    }
                } header: {
                    BilingualLabel(en: "Live Status", ru: "Текущее состояние")
                }

                if let hint = recommendation(for: battery) {
                    Section {
                        BilingualLabel(hint)
                            .font(.callout)
                            .foregroundStyle(.orange)
                    } header: {
                        BilingualLabel(en: "Recommendation", ru: "Рекомендация")
                    }
                }
            } else if noBattery {
                BilingualLabel(en: "No battery detected (desktop Mac)", ru: "Батарея не обнаружена (настольный Mac)")
            } else {
                ProgressView()
            }

            HStack {
                Button {
                    load()
                } label: {
                    BilingualLabel(en: "Refresh", ru: "Обновить")
                }
                .disabled(isRefreshing)
                if isRefreshing {
                    ProgressView().controlSize(.small)
                } else if let lastUpdated {
                    let time = lastUpdated.formatted(date: .omitted, time: .standard)
                    BilingualLabel(en: "Updated at \(time)", ru: "Обновлено в \(time)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { load() }
    }

    private func load() {
        isRefreshing = true
        Task {
            // The IOKit read is near-instant and values rarely change between
            // clicks, so without a visible beat the button looks dead. Hold the
            // spinner briefly and stamp the time so a refresh is always visible.
            async let minimumDelay: Void? = try? Task.sleep(nanoseconds: 400_000_000)
            let info = BatteryInfo.read()
            _ = await minimumDelay
            battery = info
            noBattery = (info == nil)
            lastUpdated = Date()
            isRefreshing = false
        }
    }

    private func recommendation(for battery: BatteryInfo) -> BilingualText? {
        if battery.condition.en == "Service Recommended" {
            return BilingualText(
                en: "Apple reports a permanent fault — book a Genius Bar / authorized service appointment.",
                ru: "Apple сообщает о постоянной неисправности — обратитесь в авторизованный сервис."
            )
        }
        if battery.healthPercent < 80 {
            return BilingualText(
                en: "Battery health is below 80% — expect reduced runtime; consider a battery replacement.",
                ru: "Износ батареи выше 20% — время работы заметно снижено, стоит задуматься о замене."
            )
        }
        if let temp = battery.temperatureCelsius, temp > 40 {
            return BilingualText(
                en: "Battery temperature is high (\(String(format: "%.0f", temp))°C) — ensure vents aren't blocked and avoid charging in direct sun/heat.",
                ru: "Высокая температура батареи (\(String(format: "%.0f", temp))°C) — проверьте вентиляцию и не заряжайте на солнце/в тепле."
            )
        }
        return nil
    }
}

#Preview {
    BatteryView()
}
