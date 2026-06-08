/**
 * One-shot build: npx esbuild html/vendor/lit/build-lit.mjs --bundle --platform=browser --format=iife --global-name=Lit --outfile=html/vendor/lit/lit.min.js --minify
 */
import { LitElement, html, css, nothing } from "lit";

globalThis.Lit = { LitElement, html, css, nothing };
