// Copyright (c) 2026 air/OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later

package versioner

// The system package manager owns every installed Bridge version on air/OS.
func (v *Versioner) RemoveCurrentVersion() error { return ErrNoRemoveBase }
