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
	export class SnapshotResult {
	    ok: boolean;
	    base64?: string;
	    width?: number;
	    height?: number;
	    error?: string;
	
	    static createFrom(source: any = {}) {
	        return new SnapshotResult(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.ok = source["ok"];
	        this.base64 = source["base64"];
	        this.width = source["width"];
	        this.height = source["height"];
	        this.error = source["error"];
	    }
	}
	export class VoiceStatus {
	    status: string;
	    message: string;
	
	    static createFrom(source: any = {}) {
	        return new VoiceStatus(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.status = source["status"];
	        this.message = source["message"];
	    }
	}

}

