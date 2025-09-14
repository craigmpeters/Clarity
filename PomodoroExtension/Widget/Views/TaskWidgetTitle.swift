    func TaskWidgetTitle() -> HStack<TupleView<(some View, Spacer, Text)>> {
        return // Header
            HStack {
                Label(entry.filter.rawValue, systemImage: entry.filter.systemImage)
                    .font(.headline)
                    .foregroundStyle(entry.filter.color)
                
                Spacer()
                
                Text("\(entry.taskCount) tasks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
    }