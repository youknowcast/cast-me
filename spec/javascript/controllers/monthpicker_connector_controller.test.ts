import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

import MonthpickerConnectorController from "../../../app/javascript/controllers/monthpicker_connector_controller"

const flush = () => new Promise(resolve => setTimeout(resolve, 0))

const html = `
  <button id="month-picker" data-controller="monthpicker-connector"
    data-monthpicker-connector-date-value="2026-12-15"
    data-monthpicker-connector-base-url-value="/calendar"
    data-action="click->monthpicker-connector#open"></button>
`

describe("monthpicker-connector controller", () => {
  let application: Application

  beforeEach(async () => {
    document.body.innerHTML = html
    application = Application.start()
    application.register("monthpicker-connector", MonthpickerConnectorController)
    await flush()
  })

  afterEach(async () => {
    application.stop()
    document.body.innerHTML = ""
    await flush()
    vi.restoreAllMocks()
  })

  it("opens the month picker with the current date and base url", async () => {
    const listener = vi.fn()
    window.addEventListener("monthpicker:open", listener)

    document.querySelector<HTMLButtonElement>("#month-picker")!.click()
    await flush()

    expect(listener).toHaveBeenCalledOnce()
    expect(listener.mock.calls[0][0].detail).toMatchObject({
      date: "2026-12-15",
      baseUrl: "/calendar",
    })
    expect(listener.mock.calls[0][0].detail.trigger).toBe(document.querySelector("#month-picker"))

    window.removeEventListener("monthpicker:open", listener)
  })
})
