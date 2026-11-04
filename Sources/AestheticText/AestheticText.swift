//
//  AestheticText.swift
//  AestheticText
//
//  Created by Kyle Bashour on 3/15/25.
//

import SwiftUI

extension View {
    /// Wraps text "aesthetically" by compressing the views width to be as small as possible without
    /// affecting the height - in practice, making the length of lines of text as equal as possible.
    ///
    /// The method works best with centered text, as it may cause the second of two lines of text to
    /// to be longer than the first, which can look off with left or right-aligned text.
    public func aestheticText() -> some View {
        modifier(AestheticTextModifier())
    }
}

private struct AestheticTextModifier: ViewModifier {
    func body(content: Content) -> some View {
        AestheticTextLayout() {
            content
        }
    }
}

private struct AestheticTextLayout: Layout {
    struct CacheKey: Hashable {
        let width: CGFloat?
        let height: CGFloat?
    }

    typealias Cache = [CacheKey: CGSize]

    func makeCache(subviews: Subviews) -> Cache {
        [:]
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        assert(subviews.count == 1)

        guard let subview = subviews.first else {
            return .zero
        }

        let key = CacheKey(width: proposal.width, height: proposal.height)
        if let size = cache[key] {
            return size
        }

        let sizeThatFits = subview.sizeThatFits(proposal)
        let size = smallestSize(for: subview, proposal: proposal, sizeThatFits: sizeThatFits)
        cache[key] = size

        return size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        assert(subviews.count == 1)

        guard let subview = subviews.first else {
            return
        }

        let key = CacheKey(width: proposal.width, height: proposal.height)
        if let size = cache[key] {
            return subview.place(at: bounds.origin, proposal: ProposedViewSize(size))
        }

        let sizeThatFits = subview.sizeThatFits(proposal)
        let size = smallestSize(for: subview, proposal: proposal, sizeThatFits: sizeThatFits)
        cache[key] = size

        subview.place(at: bounds.origin, proposal: ProposedViewSize(size))
    }

    /// Performs a binary search to find the smallest width, up to a tuned precision,
    /// that does not affect the height (e.g., cause the text to wrap to another line).
    private func smallestSize(for subview: LayoutSubview, proposal: ProposedViewSize, sizeThatFits: CGSize) -> CGSize {
        // Measure with an unconstrained height: under a finite height proposal, narrower widths
        // truncate to the same height and look like they fit.
        let naturalHeight = subview.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil)).height

        // Already squeezed below its natural height, so narrowing would only truncate more.
        guard sizeThatFits.height >= naturalHeight else {
            return sizeThatFits
        }

        var maxWidth = sizeThatFits.width
        // It will never make sense to wrap to less than half of the current width.
        var minWidth = maxWidth * 0.5

        // Get within 10% of the smallest possible size based on the range of possible sizes.
        let precision = max(1, (maxWidth - minWidth) * 0.1)

        while maxWidth - minWidth > precision {
            let midWidth = (minWidth + maxWidth) / 2
            let testSize = subview.sizeThatFits(ProposedViewSize(width: midWidth, height: nil))

            if testSize.height <= naturalHeight {
                // Shrink further
                maxWidth = midWidth
            } else {
                // Too narrow, increase width
                minWidth = midWidth
            }
        }

        return CGSize(width: maxWidth, height: sizeThatFits.height)
    }
}
