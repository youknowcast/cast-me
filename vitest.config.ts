import { defineConfig } from "vitest/config"

export default defineConfig({
	test: {
		environment: "jsdom",
		// Run in a negative-offset zone so UTC-vs-local date-parsing bugs surface deterministically.
		env: { TZ: "America/New_York" },
		include: ["spec/javascript/**/*.test.ts"]
	}
})
