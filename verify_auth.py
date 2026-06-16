import asyncio
from playwright.async_api import async_playwright

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        page = await browser.new_page()
        try:
            import os
            abs_path = os.path.abspath("app/index.html")
            await page.goto(f"file://{abs_path}")

            # Check for syntax errors
            errors = []
            page.on("pageerror", lambda exc: errors.append(exc.message))
            await page.wait_for_timeout(2000)

            if errors:
                print(f"Detected {len(errors)} page errors:")
                for err in errors:
                    print(f" - {err}")
                exit(1)

            # Verify functions are exposed
            funcs = [
                'showAuth', 'handleLogin', 'handleSignup', 'handleLogout'
            ]
            for func in funcs:
                is_defined = await page.evaluate(f"typeof window.{func} === 'function'")
                if not is_defined:
                    print(f"Error: window.{func} is not defined")
                    exit(1)
                else:
                    print(f"Verified: window.{func} is available")

            print("Verification successful.")

        except Exception as e:
            print(f"Verification failed: {e}")
            exit(1)
        finally:
            await browser.close()

if __name__ == "__main__":
    asyncio.run(main())
