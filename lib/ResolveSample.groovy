class ResolveSample {

    static def resolveSample(meta, key) {

        def sheet = meta.sampleSheet

        for (g in sheet.groups ?: []) {
            for (s in g.samples ?: []) {
                if (s.files*.name.contains(key)) {
                    return [
                        sample_id   : s.id,
                        sample_name : s.name,
                        group_id    : g.id,
                        group_name  : g.name
                    ]
                }
            }
        }

        for (s in sheet.ungroupedSamples ?: []) {
            if (s.files*.name.contains(key)) {
                return [
                    sample_id   : s.id,
                    sample_name : s.name,
                    group_id    : null,
                    group_name  : null
                ]
            }
        }

        return null
    }
}
