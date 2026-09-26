//
//  ContentView.swift
//  moonbeam-app
//
//  Created by TC on 9/23/26.
//
//  ⚠️ SPIKE UI — replace in task #4 ("Build the SwiftUI table").
//
//  Deliberately unstyled: it proves the data flows from the Astronomy Engine
//  through a view model and onto the screen, nothing more. The designed table
//  replaces this wholesale, at which point this file and
//  SpikeMoonTableViewModel go away.
//

import SwiftUI

struct ContentView: View {
    let viewModel: SpikeMoonTableViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.place.name)
            Text(viewModel.dayText)

            LabeledContent("Moonrise", value: viewModel.riseText)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(viewModel.riseAccessibilityLabel)

            LabeledContent("Moonset", value: viewModel.setText)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(viewModel.setAccessibilityLabel)

            LabeledContent("Phase", value: viewModel.phaseText)

            LabeledContent("Illuminated", value: viewModel.illuminationText)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(viewModel.illuminationAccessibilityLabel)

            Text("Spike UI — replaced in task #4")
        }
        .padding()
    }
}

#Preview {
    ContentView(
        viewModel: SpikeMoonTableViewModel(moonService: AstronomyEngineMoonService())
    )
}
