import asyncio
from playwright.async_api import async_playwright

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        page = await browser.new_page()
        # Test loading the app
        try:
            # Using file path for simplicity
            import os
            abs_path = os.path.abspath("app/index.html")
            await page.goto(f"file://{abs_path}")

            # Check for console errors
            errors = []
            page.on("pageerror", lambda exc: errors.append(exc.message))

            await page.wait_for_timeout(2000)

            if errors:
                print(f"Detected {len(errors)} page errors:")
                for err in errors:
                    print(f" - {err}")
                exit(1)
            else:
                print("No syntax or runtime errors detected on load.")

            # Take a screenshot to verify UI is intact
            await page.screenshot(path="verify_final_fixed.png")
            print("Screenshot saved to verify_final_fixed.png")

        except Exception as e:
            print(f"Verification failed: {e}")
            exit(1)
        finally:
            await browser.close()

if __name__ == "__main__":
    asyncio.run(main())
