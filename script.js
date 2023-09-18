// script.js
const cartePrincipale = document.querySelector('.carte-principale');

cartePrincipale.addEventListener('mouseover', () => {
    // Ajoutez ici les effets que vous souhaitez, par exemple changer la couleur de fond.
    cartePrincipale.style.backgroundColor = 'lightgray';
});

cartePrincipale.addEventListener('mouseout', () => {
    // Rétablissez les styles par défaut lorsque le curseur quitte la carte.
    cartePrincipale.style.backgroundColor = '';
});


let menubar = document.querySelector('#menu-bars')
let mynav = document.querySelector('.navbar');

menubar.onclick = () =>{
    menubar.classList.toggle('fa-times');
    mynav.classList.toggle('active');
}


// Example starter JavaScript for disabling form submissions if there are invalid fields
(function () {
    'use strict'
  
    // Fetch all the forms we want to apply custom Bootstrap validation styles to
    var forms = document.querySelectorAll('.needs-validation')
  
    // Loop over them and prevent submission
    Array.prototype.slice.call(forms)
      .forEach(function (form) {
        form.addEventListener('submit', function (event) {
          if (!form.checkValidity()) {
            event.preventDefault()
            event.stopPropagation()
          }
  
          form.classList.add('was-validated')
        }, false)
      })
  })()


  const popover = new bootstrap.Popover('.popover-dismiss', {
    trigger: 'focus'
  })