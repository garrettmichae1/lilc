/** Canonical public legal URLs (GitHub Pages). Same as the iPhone app. */
export const LegalURLs = {
  home: "https://garrettmichae1.github.io/lilc/",
  privacy: "https://garrettmichae1.github.io/lilc/privacy.html",
  terms: "https://garrettmichae1.github.io/lilc/terms.html",
  teachers: "https://garrettmichae1.github.io/lilc/teachers.html",
  webPlayground: "https://garrettmichae1.github.io/lilc/web/",
  support: "mailto:support@lilc.app?subject=lilC%20Support",
} as const;

export const APP_VERSION = "0.1.0 (web)";

/** Teachers, licenses, and email stay compiled but hidden in this learning release. */
export const EXTRA_LEGAL_ROWS_VISIBLE = false;

export const PICO_C_EXPLANATION = `PicoC is an interpreter, not a compiler. It runs C in this browser. Standard C libraries and extras a desktop compiler provides will not work here.`;

export const LICENSES_BODY = `PicoC
Copyright (c) 2009-2011, Zik Saleeba
Copyright (c) 2015, Joseph Poirier
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
* Neither the name of the Zik Saleeba nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.

lilC source (except vendored PicoC) is licensed under the Apache License 2.0. See LICENSE, NOTICE, and TRADEMARKS.md in the project repository.`;
