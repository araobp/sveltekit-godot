import { json } from "@sveltejs/kit";
import type { RequestHandler } from "@sveltejs/kit";

var ldContent: string | null = null;

export const GET: RequestHandler = async ({ }) => {
    return json({ ld_content: ldContent });
}

export const POST: RequestHandler = async ({ request }) => {
    const { ld_content } = await request.json();
    ldContent = ld_content;
    return json({ success: true });
}