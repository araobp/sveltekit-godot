import adapter from "@sveltejs/adapter-static";

/** @type {import('@sveltejs/kit').Config} */
const config = {
	kit: {
		adapter: adapter(
			{
				pages: "../docs/live",
				assets: "../docs/live",
			}
		),
		paths: {
			base: process.env.NODE_ENV === "production" ? "/sveltekit-gh-pages" : "",
		},
	},
};

export default config;
