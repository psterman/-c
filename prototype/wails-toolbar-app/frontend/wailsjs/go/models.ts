export namespace main {
	
	export class ProcessResult {
	    ok: boolean;
	    message: string;
	    data?: string;
	
	    static createFrom(source: any = {}) {
	        return new ProcessResult(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.ok = source["ok"];
	        this.message = source["message"];
	        this.data = source["data"];
	    }
	}
	export class QuickAction {
	    id: string;
	    label: string;
	    desc: string;
	    keywords: string[];
	    matched: boolean;
	    score: number;
	
	    static createFrom(source: any = {}) {
	        return new QuickAction(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.id = source["id"];
	        this.label = source["label"];
	        this.desc = source["desc"];
	        this.keywords = source["keywords"];
	        this.matched = source["matched"];
	        this.score = source["score"];
	    }
	}

}

