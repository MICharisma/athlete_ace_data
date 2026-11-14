require "cgi"
require "json"

root = File.expand_path("..", __dir__)
entries = JSON.parse(File.read(File.join(root, "sources/coverage_2026/visual_assets.json")))
cards = entries.map do |entry|
  path = CGI.escapeHTML(entry.fetch("path").delete_prefix("media/"))
  name = CGI.escapeHTML(entry.fetch("name"))
  kind = CGI.escapeHTML(entry.fetch("kind"))
  picture = path.end_with?(".glb") ? %(<canvas data-model="#{path}" width="360" height="260" aria-label="#{name}"></canvas>) : %(<img src="#{path}" alt="#{name}" loading="lazy">)
  %(<article>#{picture}<div><small>#{kind}</small><h2>#{name}</h2><a href="#{path}">Open canonical file</a></div></article>)
end.join("\n")
html = <<~HTML
  <!doctype html>
  <html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Seed asset library</title>
  <style>
    *{box-sizing:border-box}body{margin:0;background:#f4f5f7;color:#17212d;font:16px system-ui,sans-serif}main{max-width:1280px;margin:auto;padding:48px 24px}h1{font-size:36px;margin:4px 0 16px}header p{max-width:800px;line-height:1.6;color:#526171}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(270px,1fr));gap:20px;margin-top:30px}article{overflow:hidden;border:1px solid #dce1e7;border-radius:12px;background:white}article>img,canvas{display:block;width:100%;height:260px;object-fit:contain;background:#e9edf2;padding:16px}canvas{padding:0;cursor:grab;touch-action:none}article>div{padding:20px}small{font-size:12px;text-transform:uppercase;letter-spacing:.07em;color:#60748a}h2{font-size:18px;margin:8px 0 18px}a{color:#235f98;font-size:14px}code{font-size:13px}#status{color:#526171}
  </style>
  <main><header><small>AthleteAce seed library</small><h1>Logos and uniform assets</h1><p>Source images sit beside illustrative SVG and self-contained 3D representations. Uniform pieces have local names. Drag a 3D preview to rotate it. These schematic meshes demonstrate the file pipeline and are not accurate garment models.</p><p id="status">Loading 3D files…</p></header><section class="grid">#{cards}</section></main>
  <script>
    const models = [...document.querySelectorAll('canvas')];
    Promise.all(models.map(async canvas => {
      const response = await fetch(canvas.dataset.model);
      if (!response.ok) throw new Error('Missing model: '+canvas.dataset.model);
      const buffer = await response.arrayBuffer(), view = new DataView(buffer);
      if (view.getUint32(0,true)!==0x46546c67 || view.getUint32(8,true)!==buffer.byteLength) throw new Error('Invalid GLB');
      const jsonLength = view.getUint32(12,true);
      const gltf = JSON.parse(new TextDecoder().decode(new Uint8Array(buffer,20,jsonLength)));
      const binaryOffset = 20+jsonLength+8;
      const positions = new Float32Array(buffer,binaryOffset+gltf.bufferViews[0].byteOffset,gltf.accessors[0].count*3);
      const indices = new Uint16Array(buffer,binaryOffset+gltf.bufferViews[1].byteOffset,gltf.accessors[1].count);
      const rgb = gltf.materials[0].pbrMetallicRoughness.baseColorFactor.slice(0,3);
      let angle=.38;
      const draw = () => {
        const context=canvas.getContext('2d');context.fillStyle='#e9edf2';context.fillRect(0,0,360,260);
        const points=[];
        for(let i=0;i<positions.length;i+=3){const x=positions[i],y=positions[i+1]-.25,z=positions[i+2];points.push([x*Math.cos(angle)+z*Math.sin(angle),y,-x*Math.sin(angle)+z*Math.cos(angle)]);}
        const triangles=[];
        for(let i=0;i<indices.length;i+=3){const vertices=[points[indices[i]],points[indices[i+1]],points[indices[i+2]]];if(vertices.some(p=>!p))throw new Error('Invalid mesh index');triangles.push(vertices);}
        triangles.sort((a,b)=>a.reduce((n,p)=>n+p[2],0)-b.reduce((n,p)=>n+p[2],0));
        for(const triangle of triangles){const depth=triangle.reduce((n,p)=>n+p[2],0)/3,shade=.8+depth*.2;context.fillStyle='rgb('+rgb.map(c=>Math.min(255,Math.round(c*255*shade))).join(',')+')';context.strokeStyle='#56708633';context.beginPath();triangle.forEach((p,i)=>context[i?'lineTo':'moveTo'](180+p[0]*98,130-p[1]*98));context.closePath();context.fill();context.stroke();}
      };
      let dragging=false,lastX;
      canvas.onpointerdown=event=>{dragging=true;lastX=event.clientX;canvas.setPointerCapture(event.pointerId);};
      canvas.onpointerup=()=>dragging=false;
      canvas.onpointermove=event=>{if(dragging){angle+=(event.clientX-lastX)*.015;lastX=event.clientX;draw();}};
      draw();
    })).then(()=>{document.querySelector('#status').textContent=models.length+' 3D files loaded and rendered.';document.documentElement.dataset.models='ready';}).catch(error=>{document.querySelector('#status').textContent=error.message;document.documentElement.dataset.models='failed';});
  </script></html>
HTML
File.write(File.join(root, "media/index.html"), html)
puts "Wrote #{entries.size} asset previews to media/index.html"
